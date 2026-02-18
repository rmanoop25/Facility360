<?php

declare(strict_types=1);

namespace App\Filament\Resources\TimeExtensionRequestResource\Pages;

use App\Enums\ExtensionStatus;
use App\Filament\Resources\TimeExtensionRequestResource;
use App\Models\TimeExtensionRequest;
use App\Services\TimeSlotAvailabilityService;
use Carbon\Carbon;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ViewRecord;
use Illuminate\Support\Facades\DB;

class ViewTimeExtensionRequest extends ViewRecord
{
    protected static string $resource = TimeExtensionRequestResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('approve')
                ->label(__('extensions.actions.approve'))
                ->icon('heroicon-o-check-circle')
                ->color('success')
                ->authorize('approve')
                ->visible(fn (): bool => $this->record->isPending())
                ->form([
                    Textarea::make('admin_notes')
                        ->label(__('extensions.fields.admin_notes'))
                        ->rows(3)
                        ->maxLength(1000),
                ])
                ->action(function (array $data, Action $action): void {
                    /** @var TimeExtensionRequest $extension */
                    $extension = $this->record;
                    $assignment = $extension->assignment;

                    if ($assignment->assigned_end_time && $assignment->assigned_start_time) {
                        $currentEnd = Carbon::parse($assignment->assigned_end_time);
                        $newEnd = $currentEnd->copy()->addMinutes($extension->requested_minutes);
                        $checkDate = Carbon::parse($assignment->scheduled_end_date ?? $assignment->scheduled_date);

                        $hasConflict = app(TimeSlotAvailabilityService::class)->hasOverlap(
                            $assignment->service_provider_id,
                            $checkDate,
                            $currentEnd->format('H:i:s'),
                            $newEnd->format('H:i:s'),
                            $assignment->id
                        );

                        if ($hasConflict) {
                            Notification::make()
                                ->danger()
                                ->title(__('extensions.overlap_conflict', [
                                    'minutes' => $extension->requested_minutes,
                                ]))
                                ->send();

                            $action->halt();

                            return;
                        }
                    }

                    DB::transaction(function () use ($extension, $assignment, $data): void {
                        if ($assignment->assigned_end_time && $assignment->assigned_start_time) {
                            $newEnd = Carbon::parse($assignment->assigned_end_time)
                                ->addMinutes($extension->requested_minutes);

                            $assignment->update([
                                'assigned_end_time' => $newEnd->format('H:i:s'),
                            ]);
                        }

                        $extension->update([
                            'status' => ExtensionStatus::APPROVED,
                            'responded_by' => auth()->id(),
                            'admin_notes' => $data['admin_notes'] ?? null,
                            'responded_at' => now(),
                        ]);
                    });

                    Notification::make()
                        ->success()
                        ->title(__('extensions.approved_successfully'))
                        ->send();

                    $this->refreshFormData(['status', 'responded_by', 'admin_notes', 'responded_at']);
                }),

            Action::make('reject')
                ->label(__('extensions.actions.reject'))
                ->icon('heroicon-o-x-circle')
                ->color('danger')
                ->authorize('reject')
                ->visible(fn (): bool => $this->record->isPending())
                ->form([
                    Textarea::make('admin_notes')
                        ->label(__('extensions.fields.rejection_reason'))
                        ->required()
                        ->rows(3)
                        ->minLength(10)
                        ->maxLength(1000),
                ])
                ->action(function (array $data): void {
                    $this->record->update([
                        'status' => ExtensionStatus::REJECTED,
                        'responded_by' => auth()->id(),
                        'admin_notes' => $data['admin_notes'],
                        'responded_at' => now(),
                    ]);

                    Notification::make()
                        ->success()
                        ->title(__('extensions.rejected_successfully'))
                        ->send();

                    $this->refreshFormData(['status', 'responded_by', 'admin_notes', 'responded_at']);
                }),
        ];
    }
}
