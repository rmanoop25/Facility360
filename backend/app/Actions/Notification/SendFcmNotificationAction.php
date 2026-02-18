<?php

declare(strict_types=1);

namespace App\Actions\Notification;

use App\Enums\NotificationType;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Firebase\Exception\MessagingException;

class SendFcmNotificationAction
{
    private ?Messaging $messaging = null;
    private bool $isConfigured = false;

    public function __construct()
    {
        try {
            // Only initialize Firebase if credentials exist
            $credentialsPath = config('firebase.projects.app.credentials');
            if ($credentialsPath && file_exists(base_path($credentialsPath))) {
                $this->messaging = app(Messaging::class);
                $this->isConfigured = true;
                Log::info('FCM: Firebase initialized successfully');
            } else {
                Log::info('FCM: Firebase credentials not configured, notifications disabled');
            }
        } catch (\Throwable $e) {
            Log::warning('FCM: Failed to initialize Firebase', ['error' => $e->getMessage()]);
            $this->isConfigured = false;
        }
    }

    /**
     * Check if FCM is properly configured.
     */
    public function isConfigured(): bool
    {
        return $this->isConfigured && $this->messaging !== null;
    }

    /**
     * Send FCM notification to a single user.
     */
    public function toUser(
        User $user,
        NotificationType $type,
        array $data = [],
        ?string $customTitle = null,
        ?string $customBody = null
    ): bool {
        if (!$this->isConfigured()) {
            return false;
        }

        if (empty($user->fcm_token)) {
            Log::info('FCM: User has no FCM token', ['user_id' => $user->id]);
            return false;
        }

        $locale = $user->locale ?? config('app.locale', 'en');
        
        // Temporarily set locale for proper translation
        $currentLocale = app()->getLocale();
        app()->setLocale($locale);

        try {
            $title = $customTitle ?? $type->title($locale);
            $body = $customBody ?? $type->body($locale, $data);

            return $this->send(
                token: $user->fcm_token,
                title: $title,
                body: $body,
                data: array_merge($data, [
                    'type' => $type->value,
                    'channel' => $type->channel(),
                ])
            );
        } finally {
            // Restore original locale
            app()->setLocale($currentLocale);
        }
    }

    /**
     * Send FCM notification to multiple users.
     */
    public function toUsers(
        iterable $users,
        NotificationType $type,
        array $data = [],
        ?string $customTitle = null,
        ?string $customBody = null
    ): array {
        $results = ['success' => 0, 'failed' => 0];

        foreach ($users as $user) {
            if ($this->toUser($user, $type, $data, $customTitle, $customBody)) {
                $results['success']++;
            } else {
                $results['failed']++;
            }
        }

        return $results;
    }

    /**
     * Send FCM notification to a topic.
     */
    public function toTopic(
        string $topic,
        NotificationType $type,
        array $data = [],
        string $locale = 'en',
        ?string $customTitle = null,
        ?string $customBody = null
    ): bool {
        if (!$this->isConfigured()) {
            return false;
        }

        // Temporarily set locale for proper translation
        $currentLocale = app()->getLocale();
        app()->setLocale($locale);

        try {
            $title = $customTitle ?? $type->title($locale);
            $body = $customBody ?? $type->body($locale, $data);

            return $this->sendToTopic(
                topic: $topic,
                title: $title,
                body: $body,
                data: array_merge($data, [
                    'type' => $type->value,
                    'channel' => $type->channel(),
                ])
            );
        } finally {
            // Restore original locale
            app()->setLocale($currentLocale);
        }
    }

    /**
     * Send raw FCM message to a device token.
     */
    public function send(
        string $token,
        string $title,
        string $body,
        array $data = []
    ): bool {
        if (!$this->isConfigured()) {
            return false;
        }

        try {
            $message = CloudMessage::withTarget('token', $token)
                ->withNotification(Notification::create($title, $body))
                ->withData($this->sanitizeData($data));

            $this->messaging->send($message);

            Log::info('FCM: Notification sent successfully', [
                'token' => substr($token, 0, 20) . '...',
                'title' => $title,
            ]);

            return true;
        } catch (MessagingException $e) {
            Log::error('FCM: Failed to send notification', [
                'error' => $e->getMessage(),
                'token' => substr($token, 0, 20) . '...',
            ]);

            // Handle invalid token - could be used to clean up stale tokens
            if ($this->isInvalidTokenError($e)) {
                Log::warning('FCM: Invalid token detected', [
                    'token' => substr($token, 0, 20) . '...',
                ]);
            }

            return false;
        } catch (\Throwable $e) {
            Log::error('FCM: Unexpected error', [
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Send FCM message to a topic.
     */
    public function sendToTopic(
        string $topic,
        string $title,
        string $body,
        array $data = []
    ): bool {
        if (!$this->isConfigured()) {
            return false;
        }

        try {
            $message = CloudMessage::withTarget('topic', $topic)
                ->withNotification(Notification::create($title, $body))
                ->withData($this->sanitizeData($data));

            $this->messaging->send($message);

            Log::info('FCM: Topic notification sent', [
                'topic' => $topic,
                'title' => $title,
            ]);

            return true;
        } catch (\Throwable $e) {
            Log::error('FCM: Failed to send topic notification', [
                'error' => $e->getMessage(),
                'topic' => $topic,
            ]);

            return false;
        }
    }

    /**
     * Subscribe a token to a topic.
     */
    public function subscribeToTopic(string $token, string $topic): bool
    {
        if (!$this->isConfigured()) {
            return false;
        }

        try {
            $this->messaging->subscribeToTopic($topic, [$token]);
            return true;
        } catch (\Throwable $e) {
            Log::error('FCM: Failed to subscribe to topic', [
                'error' => $e->getMessage(),
                'topic' => $topic,
            ]);
            return false;
        }
    }

    /**
     * Unsubscribe a token from a topic.
     */
    public function unsubscribeFromTopic(string $token, string $topic): bool
    {
        if (!$this->isConfigured()) {
            return false;
        }

        try {
            $this->messaging->unsubscribeFromTopic($topic, [$token]);
            return true;
        } catch (\Throwable $e) {
            Log::error('FCM: Failed to unsubscribe from topic', [
                'error' => $e->getMessage(),
                'topic' => $topic,
            ]);
            return false;
        }
    }

    /**
     * Sanitize data array for FCM (all values must be strings).
     */
    private function sanitizeData(array $data): array
    {
        return array_map(function ($value) {
            if (is_array($value)) {
                return json_encode($value);
            }
            if (is_bool($value)) {
                return $value ? 'true' : 'false';
            }
            return (string) $value;
        }, $data);
    }

    /**
     * Check if the error is due to an invalid token.
     */
    private function isInvalidTokenError(MessagingException $e): bool
    {
        $message = strtolower($e->getMessage());
        return str_contains($message, 'not a valid fcm')
            || str_contains($message, 'unregistered')
            || str_contains($message, 'invalid registration');
    }
}
