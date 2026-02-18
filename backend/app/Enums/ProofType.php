<?php

declare(strict_types=1);

namespace App\Enums;

enum ProofType: string
{
    case PHOTO = 'photo';
    case VIDEO = 'video';
    case AUDIO = 'audio';
    case PDF = 'pdf';

    public function label(): string
    {
        return match ($this) {
            self::PHOTO => __('proof.types.photo'),
            self::VIDEO => __('proof.types.video'),
            self::AUDIO => __('proof.types.audio'),
            self::PDF => __('proof.types.pdf'),
        };
    }

    public function icon(): string
    {
        return match ($this) {
            self::PHOTO => 'heroicon-o-photo',
            self::VIDEO => 'heroicon-o-video-camera',
            self::AUDIO => 'heroicon-o-microphone',
            self::PDF => 'heroicon-o-document',
        };
    }

    public function mimeTypes(): array
    {
        return match ($this) {
            self::PHOTO => ['image/jpeg', 'image/png'],
            self::VIDEO => ['video/mp4'],
            self::AUDIO => ['audio/mpeg'],
            self::PDF => ['application/pdf'],
        };
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
