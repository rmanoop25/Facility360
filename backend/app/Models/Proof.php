<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\ProofStage;
use App\Enums\ProofType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

class Proof extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'issue_assignment_id',
        'type',
        'file_path',
        'stage',
    ];

    protected function casts(): array
    {
        return [
            'type' => ProofType::class,
            'stage' => ProofStage::class,
            'uploaded_at' => 'datetime',
        ];
    }

    // Relationships
    public function assignment(): BelongsTo
    {
        return $this->belongsTo(IssueAssignment::class, 'issue_assignment_id');
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
    public function scopeDuringWork($query)
    {
        return $query->where('stage', ProofStage::DURING_WORK);
    }

    public function scopeCompletion($query)
    {
        return $query->where('stage', ProofStage::COMPLETION);
    }

    public function scopePhotos($query)
    {
        return $query->where('type', ProofType::PHOTO);
    }

    public function scopeVideos($query)
    {
        return $query->where('type', ProofType::VIDEO);
    }

    public function scopeAudio($query)
    {
        return $query->where('type', ProofType::AUDIO);
    }

    public function scopePdfs($query)
    {
        return $query->where('type', ProofType::PDF);
    }

    // Helpers
    public function isPhoto(): bool
    {
        return $this->type === ProofType::PHOTO;
    }

    public function isVideo(): bool
    {
        return $this->type === ProofType::VIDEO;
    }

    public function isAudio(): bool
    {
        return $this->type === ProofType::AUDIO;
    }

    public function isPdf(): bool
    {
        return $this->type === ProofType::PDF;
    }

    public function getExtensionAttribute(): string
    {
        return pathinfo($this->file_path, PATHINFO_EXTENSION);
    }
}
