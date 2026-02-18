<?php

declare(strict_types=1);

namespace App\Enums;

enum AssignmentStatus: string
{
    case ASSIGNED = 'assigned';
    case IN_PROGRESS = 'in_progress';
    case ON_HOLD = 'on_hold';
    case FINISHED = 'finished';
    case COMPLETED = 'completed';

    public function label(): string
    {
        return match ($this) {
            self::ASSIGNED => __('assignments.status.assigned'),
            self::IN_PROGRESS => __('assignments.status.in_progress'),
            self::ON_HOLD => __('assignments.status.on_hold'),
            self::FINISHED => __('assignments.status.finished'),
            self::COMPLETED => __('assignments.status.completed'),
        };
    }

    public function color(): string
    {
        return match ($this) {
            self::ASSIGNED => 'info',
            self::IN_PROGRESS => 'primary',
            self::ON_HOLD => 'gray',
            self::FINISHED => 'success',
            self::COMPLETED => 'success',
        };
    }

    public function icon(): string
    {
        return match ($this) {
            self::ASSIGNED => 'heroicon-o-user-plus',
            self::IN_PROGRESS => 'heroicon-o-wrench-screwdriver',
            self::ON_HOLD => 'heroicon-o-pause-circle',
            self::FINISHED => 'heroicon-o-check-circle',
            self::COMPLETED => 'heroicon-o-check-badge',
        };
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public static function options(): array
    {
        return collect(self::cases())
            ->mapWithKeys(fn (self $status) => [$status->value => $status->label()])
            ->toArray();
    }
}
