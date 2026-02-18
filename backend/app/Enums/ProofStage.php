<?php

declare(strict_types=1);

namespace App\Enums;

enum ProofStage: string
{
    case DURING_WORK = 'during_work';
    case COMPLETION = 'completion';

    public function label(): string
    {
        return match ($this) {
            self::DURING_WORK => __('proof.stages.during_work'),
            self::COMPLETION => __('proof.stages.completion'),
        };
    }

    public function icon(): string
    {
        return match ($this) {
            self::DURING_WORK => 'heroicon-o-wrench-screwdriver',
            self::COMPLETION => 'heroicon-o-check-circle',
        };
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
