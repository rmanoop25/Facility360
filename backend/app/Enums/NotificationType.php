<?php

declare(strict_types=1);

namespace App\Enums;

enum NotificationType: string
{
    case ISSUE_CREATED = 'issue_created';
    case ISSUE_ASSIGNED = 'issue_assigned';
    case WORK_STARTED = 'work_started';
    case WORK_ON_HOLD = 'work_on_hold';
    case WORK_RESUMED = 'work_resumed';
    case WORK_FINISHED = 'work_finished';
    case ASSIGNMENT_APPROVED = 'assignment_approved';
    case PARTIAL_PROGRESS = 'partial_progress';
    case ISSUE_COMPLETED = 'issue_completed';
    case ISSUE_CANCELLED = 'issue_cancelled';
    case GENERAL = 'general';

    public function title(string $locale = 'en'): string
    {
        return __('notifications.messages.'.$this->value.'.title', [], $locale);
    }

    public function body(string $locale = 'en', array $params = []): string
    {
        return __('notifications.messages.'.$this->value.'.body', $params, $locale);
    }

    public function channel(): string
    {
        return match ($this) {
            self::ISSUE_CREATED,
            self::ISSUE_ASSIGNED,
            self::WORK_STARTED,
            self::WORK_ON_HOLD,
            self::WORK_RESUMED,
            self::WORK_FINISHED,
            self::ASSIGNMENT_APPROVED,
            self::PARTIAL_PROGRESS,
            self::ISSUE_COMPLETED,
            self::ISSUE_CANCELLED => 'issues',
            self::GENERAL => 'general',
        };
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
