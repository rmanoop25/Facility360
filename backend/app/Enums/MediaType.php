<?php

declare(strict_types=1);

namespace App\Enums;

enum MediaType: string
{
    case PHOTO = 'photo';
    case VIDEO = 'video';
    case AUDIO = 'audio';
    case PDF = 'pdf';

    public function label(): string
    {
        return match ($this) {
            self::PHOTO => __('media.types.photo'),
            self::VIDEO => __('media.types.video'),
            self::AUDIO => __('media.types.audio'),
            self::PDF => __('media.types.pdf'),
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

    /**
     * Get maximum file size in kilobytes for this media type
     */
    public function maxSizeKb(): int
    {
        return match ($this) {
            self::PHOTO => 10240,   // 10MB
            self::VIDEO => 102400,  // 100MB
            self::AUDIO => 20480,   // 20MB
            self::PDF => 20480,     // 20MB
        };
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
