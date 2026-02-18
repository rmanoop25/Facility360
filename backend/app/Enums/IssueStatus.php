<?php

declare(strict_types=1);

namespace App\Enums;

enum IssueStatus: string
{
    case PENDING = 'pending';
    case ASSIGNED = 'assigned';
    case IN_PROGRESS = 'in_progress';
    case ON_HOLD = 'on_hold';
    case FINISHED = 'finished';
    case COMPLETED = 'completed';
    case CANCELLED = 'cancelled';

    public function label(): string
    {
        return match ($this) {
            self::PENDING => __('issues.status.pending'),
            self::ASSIGNED => __('issues.status.assigned'),
            self::IN_PROGRESS => __('issues.status.in_progress'),
            self::ON_HOLD => __('issues.status.on_hold'),
            self::FINISHED => __('issues.status.finished'),
            self::COMPLETED => __('issues.status.completed'),
            self::CANCELLED => __('issues.status.cancelled'),
        };
    }

    public function color(): string
    {
        return match ($this) {
            self::PENDING => 'warning',
            self::ASSIGNED => 'info',
            self::IN_PROGRESS => 'primary',
            self::ON_HOLD => 'gray',
            self::FINISHED => 'success',
            self::COMPLETED => 'success',
            self::CANCELLED => 'danger',
        };
    }

    public function icon(): string
    {
        return match ($this) {
            self::PENDING => 'heroicon-o-clock',
            self::ASSIGNED => 'heroicon-o-user-plus',
            self::IN_PROGRESS => 'heroicon-o-wrench-screwdriver',
            self::ON_HOLD => 'heroicon-o-pause-circle',
            self::FINISHED => 'heroicon-o-check-circle',
            self::COMPLETED => 'heroicon-o-check-badge',
            self::CANCELLED => 'heroicon-o-x-circle',
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
