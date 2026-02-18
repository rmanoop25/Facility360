<?php

declare(strict_types=1);

namespace App\Enums;

enum IssuePriority: string
{
    case LOW = 'low';
    case MEDIUM = 'medium';
    case HIGH = 'high';

    public function label(): string
    {
        return match ($this) {
            self::LOW => __('issues.priority.low'),
            self::MEDIUM => __('issues.priority.medium'),
            self::HIGH => __('issues.priority.high'),
        };
    }

    public function color(): string
    {
        return match ($this) {
            self::LOW => 'gray',
            self::MEDIUM => 'warning',
            self::HIGH => 'danger',
        };
    }

    public function icon(): string
    {
        return match ($this) {
            self::LOW => 'heroicon-o-arrow-down',
            self::MEDIUM => 'heroicon-o-minus',
            self::HIGH => 'heroicon-o-arrow-up',
        };
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public static function options(): array
    {
        return collect(self::cases())
            ->mapWithKeys(fn (self $priority) => [$priority->value => $priority->label()])
            ->toArray();
    }
}
