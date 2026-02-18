<?php

declare(strict_types=1);

namespace App\Filament\Resources\IssueResource\Pages;

use App\Enums\MediaType;
use App\Filament\Resources\IssueResource;
use App\Models\IssueMedia;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Storage;

class EditIssue extends EditRecord
{
    protected static string $resource = IssueResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            Actions\DeleteAction::make(),
        ];
    }

    protected function afterSave(): void
    {
        $uploadedPaths = $this->data['media_uploads'] ?? [];

        if (empty($uploadedPaths)) {
            return;
        }

        foreach ($uploadedPaths as $tempPath) {
            $fullPath = Storage::disk('public')->path($tempPath);
            $mimeType = mime_content_type($fullPath) ?: 'image/jpeg';

            $type = match (true) {
                str_starts_with($mimeType, 'video/') => MediaType::VIDEO,
                str_starts_with($mimeType, 'audio/') => MediaType::AUDIO,
                $mimeType === 'application/pdf' => MediaType::PDF,
                default => MediaType::PHOTO,
            };

            $newPath = "issues/{$this->record->id}/".basename($tempPath);
            Storage::disk('public')->move($tempPath, $newPath);

            IssueMedia::create([
                'issue_id' => $this->record->id,
                'type' => $type,
                'file_path' => $newPath,
            ]);
        }
    }
}
