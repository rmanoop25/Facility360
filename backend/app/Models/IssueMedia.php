<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\MediaType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

class IssueMedia extends Model
{
    public $timestamps = false;

    protected $table = 'issue_media';

    protected $fillable = [
        'issue_id',
        'type',
        'file_path',
    ];

    protected function casts(): array
    {
        return [
            'type' => MediaType::class,
            'uploaded_at' => 'datetime',
        ];
    }

    // Relationships
    public function issue(): BelongsTo
    {
        return $this->belongsTo(Issue::class);
    }

    // Accessors
    public function getUrlAttribute(): string
    {
        return Storage::disk('public')->url($this->file_path);
    }

    public function getFullPathAttribute(): string
    {
        return Storage::disk('public')->path($this->file_path);
    }

    // Scopes
    public function scopePhotos($query)
    {
        return $query->where('type', MediaType::PHOTO);
    }

    public function scopeVideos($query)
    {
        return $query->where('type', MediaType::VIDEO);
    }

    public function scopeAudio($query)
    {
        return $query->where('type', MediaType::AUDIO);
    }

    public function scopePdfs($query)
    {
        return $query->where('type', MediaType::PDF);
    }

    // Helpers
    public function isPhoto(): bool
    {
        return $this->type === MediaType::PHOTO;
    }

    public function isVideo(): bool
    {
        return $this->type === MediaType::VIDEO;
    }

    public function isAudio(): bool
    {
        return $this->type === MediaType::AUDIO;
    }

    public function isPdf(): bool
    {
        return $this->type === MediaType::PDF;
    }

    public function getExtensionAttribute(): string
    {
        return pathinfo($this->file_path, PATHINFO_EXTENSION);
    }
}
