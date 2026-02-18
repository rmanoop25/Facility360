<?php

declare(strict_types=1);

namespace App\Enums;

enum TimelineAction: string
{
    case CREATED = 'created';
    case ASSIGNED = 'assigned';
    case ASSIGNMENT_UPDATED = 'assignment_updated';
    case STARTED = 'started';
    case HELD = 'held';
    case RESUMED = 'resumed';
    case FINISHED = 'finished';
    case APPROVED = 'approved';
    case CANCELLED = 'cancelled';
    case UPDATED = 'updated';

    public function label(): string
    {
        return match ($this) {
            self::CREATED => __('timeline.actions.created'),
            self::ASSIGNED => __('timeline.actions.assigned'),
            self::ASSIGNMENT_UPDATED => __('timeline.actions.assignment_updated'),
            self::STARTED => __('timeline.actions.started'),
            self::HELD => __('timeline.actions.held'),
            self::RESUMED => __('timeline.actions.resumed'),
            self::FINISHED => __('timeline.actions.finished'),
            self::APPROVED => __('timeline.actions.approved'),
            self::CANCELLED => __('timeline.actions.cancelled'),
            self::UPDATED => __('timeline.actions.updated'),
        };
    }

    public function color(): string
    {
        return match ($this) {
            self::CREATED => 'info',
            self::ASSIGNED => 'primary',
            self::ASSIGNMENT_UPDATED => 'warning',
            self::STARTED => 'success',
            self::HELD => 'warning',
            self::RESUMED => 'primary',
            self::FINISHED => 'success',
            self::APPROVED => 'success',
            self::CANCELLED => 'danger',
            self::UPDATED => 'gray',
        };
    }

    public function icon(): string
    {
        return match ($this) {
            self::CREATED => 'heroicon-o-plus-circle',
            self::ASSIGNED => 'heroicon-o-user-plus',
            self::ASSIGNMENT_UPDATED => 'heroicon-o-pencil-square',
            self::STARTED => 'heroicon-o-play',
            self::HELD => 'heroicon-o-pause-circle',
            self::RESUMED => 'heroicon-o-play-circle',
            self::FINISHED => 'heroicon-o-check-circle',
            self::APPROVED => 'heroicon-o-check-badge',
            self::CANCELLED => 'heroicon-o-x-circle',
            self::UPDATED => 'heroicon-o-pencil',
        };
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
