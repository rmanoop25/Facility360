<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Enums\NotificationType;
use App\Models\Issue;
use Filament\Notifications\Notification as FilamentNotification;
use Illuminate\Notifications\Notification;

class IssueNotification extends Notification
{
    public function __construct(
        public Issue $issue,
        public NotificationType $type,
        public ?array $extraData = null
    ) {
        // Synchronous for immediate delivery in development
    }

    /**
     * Get notification delivery channels
     */
    public function via(mixed $notifiable): array
    {
        return ['database'];
    }

    /**
     * Get database representation of notification using Filament's API
     */
    public function toDatabase(mixed $notifiable): array
    {
        $locale = $notifiable->locale ?? config('app.locale', 'en');

        // Temporarily set the app locale for proper translation
        $currentLocale = app()->getLocale();
        app()->setLocale($locale);

        try {
            // Build notification using Filament's fluent API
            $notification = FilamentNotification::make()
                ->title($this->type->title($locale))
                ->body($this->type->body($locale, [
                    'title' => $this->issue->title,
                    ...($this->extraData ?? []),
                ]))
                ->icon($this->getIconForType());

            // Set color status
            $notification = match ($this->type) {
                NotificationType::ISSUE_COMPLETED, NotificationType::WORK_FINISHED => $notification->success(),
                NotificationType::ISSUE_CANCELLED => $notification->danger(),
                NotificationType::ISSUE_CREATED => $notification->warning(),
                NotificationType::ISSUE_ASSIGNED, NotificationType::GENERAL => $notification->info(),
                default => $notification,
            };

            // Get the Filament database message format
            $data = $notification->getDatabaseMessage();

            // Add custom metadata for navigation
            $data['issue_id'] = $this->issue->id;
            $data['type'] = $this->type->value;
            if ($this->extraData) {
                $data['extra'] = $this->extraData;
            }

            return $data;
        } finally {
            // Restore the original locale
            app()->setLocale($currentLocale);
        }
    }

    /**
     * Get icon for notification type
     */
    private function getIconForType(): string
    {
        return match ($this->type) {
            NotificationType::ISSUE_CREATED => 'heroicon-o-plus-circle',
            NotificationType::ISSUE_ASSIGNED => 'heroicon-o-user-plus',
            NotificationType::WORK_STARTED => 'heroicon-o-play',
            NotificationType::WORK_ON_HOLD => 'heroicon-o-pause',
            NotificationType::WORK_RESUMED => 'heroicon-o-play',
            NotificationType::WORK_FINISHED => 'heroicon-o-check-circle',
            NotificationType::ISSUE_COMPLETED => 'heroicon-o-check-badge',
            NotificationType::ISSUE_CANCELLED => 'heroicon-o-x-circle',
            NotificationType::GENERAL => 'heroicon-o-bell',
        };
    }
}
