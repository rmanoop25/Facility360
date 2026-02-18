<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use App\Enums\ExtensionStatus;
use App\Filament\Resources\TimeExtensionRequestResource\Pages;
use App\Models\TimeExtensionRequest;
use App\Services\TimeSlotAvailabilityService;
use BackedEnum;
use Carbon\Carbon;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\Textarea;
use Filament\Infolists;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Contracts\Support\Htmlable;
use Illuminate\Support\Facades\DB;

class TimeExtensionRequestResource extends Resource
{
    protected static ?string $model = TimeExtensionRequest::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-clock';

    protected static string|Htmlable|null $navigationBadgeTooltip = 'Pending Extensions';

    protected static ?int $navigationSort = 6;

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.operations');
    }

    public static function getNavigationBadge(): ?string
    {
        return (string) static::getModel()::pending()->count() ?: null;
    }

    public static function getModelLabel(): string
    {
        return __('extensions.singular');
    }

    public static function getPluralModelLabel(): string
    {
        return __('extensions.plural');
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label(__('extensions.fields.id'))
                    ->sortable(),

                Tables\Columns\TextColumn::make('assignment.issue.title')
                    ->label(__('extensions.fields.issue'))
                    ->searchable()
                    ->limit(30),

                Tables\Columns\TextColumn::make('assignment.serviceProvider.user.name')
                    ->label(__('extensions.fields.service_provider'))
                    ->searchable(),

                Tables\Columns\TextColumn::make('requested_minutes')
                    ->label(__('extensions.fields.requested_time'))
                    ->formatStateUsing(fn ($state) => $state.' '.__('work_types.minutes'))
                    ->sortable(),

                Tables\Columns\TextColumn::make('status')
                    ->label(__('extensions.fields.status'))
                    ->badge()
                    ->formatStateUsing(fn (ExtensionStatus $state) => $state->label())
                    ->color(fn (ExtensionStatus $state) => $state->color())
                    ->icon(fn (ExtensionStatus $state) => $state->icon())
                    ->sortable(),

                Tables\Columns\TextColumn::make('requested_at')
                    ->label(__('extensions.fields.requested_at'))
                    ->dateTime()
                    ->sortable(),

                Tables\Columns\TextColumn::make('responder.name')
                    ->label(__('extensions.fields.responded_by'))
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label(__('extensions.filters.status'))
                    ->options(ExtensionStatus::options())
                    ->default('pending'),
            ])
            ->actions([
                ViewAction::make(),

                Action::make('approve')
                    ->label(__('extensions.actions.approve'))
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->authorize('approve')
                    ->visible(fn (TimeExtensionRequest $record) => $record->isPending())
                    ->form([
                        Textarea::make('admin_notes')
                            ->label(__('extensions.fields.admin_notes'))
                            ->rows(3)
                            ->maxLength(1000),
                    ])
                    ->action(function (TimeExtensionRequest $record, array $data, Action $action): void {
                        $assignment = $record->assignment;

                        // If the assignment has a time range, check for conflicts
                        // before extending. Same logic as the API controller.
                        if ($assignment->assigned_end_time && $assignment->assigned_start_time) {
                            $currentEnd = Carbon::parse($assignment->assigned_end_time);
                            $newEnd = $currentEnd->copy()->addMinutes($record->requested_minutes);
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
                                        'minutes' => $record->requested_minutes,
                                    ]))
                                    ->send();

                                $action->halt();

                                return;
                            }
                        }

                        DB::transaction(function () use ($record, $assignment, $data): void {
                            // Extend assigned_end_time — automatically blocks the extra
                            // time for all future overlap checks without touching validation.
                            if ($assignment->assigned_end_time && $assignment->assigned_start_time) {
                                $newEnd = Carbon::parse($assignment->assigned_end_time)
                                    ->addMinutes($record->requested_minutes);

                                $assignment->update([
                                    'assigned_end_time' => $newEnd->format('H:i:s'),
                                ]);
                            }

                            $record->update([
                                'status' => ExtensionStatus::APPROVED,
                                'responded_by' => auth()->id(),
                                'admin_notes' => $data['admin_notes'] ?? null,
                                'responded_at' => now(),
                            ]);
                        });

                        // TODO: Send notification to SP
                    })
                    ->successNotificationTitle(__('extensions.approved_successfully')),

                Action::make('reject')
                    ->label(__('extensions.actions.reject'))
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->authorize('reject')
                    ->visible(fn (TimeExtensionRequest $record) => $record->isPending())
                    ->form([
                        Textarea::make('admin_notes')
                            ->label(__('extensions.fields.rejection_reason'))
                            ->required()
                            ->rows(3)
                            ->minLength(10)
                            ->maxLength(1000),
                    ])
                    ->action(function (TimeExtensionRequest $record, array $data): void {
                        $record->update([
                            'status' => ExtensionStatus::REJECTED,
                            'responded_by' => auth()->id(),
                            'admin_notes' => $data['admin_notes'],
                            'responded_at' => now(),
                        ]);

                        // TODO: Send notification to SP
                    })
                    ->successNotificationTitle(__('extensions.rejected_successfully')),
            ])
            ->defaultSort('requested_at', 'desc');
    }

    public static function infolist(Schema $infolist): Schema
    {
        return $infolist
            ->components([
                Section::make(__('extensions.request_info'))
                    ->schema([
                        Infolists\Components\TextEntry::make('assignment.issue.title')
                            ->label(__('extensions.fields.issue'))
                            ->url(fn (TimeExtensionRequest $record): string => route(
                                'filament.admin.resources.issues.view',
                                ['record' => $record->assignment->issue_id]
                            ))
                            ->openUrlInNewTab(),

                        Infolists\Components\TextEntry::make('assignment.serviceProvider.user.name')
                            ->label(__('extensions.fields.service_provider')),

                        Infolists\Components\TextEntry::make('requested_minutes')
                            ->label(__('extensions.fields.requested_time'))
                            ->formatStateUsing(fn ($state) => $state.' '.__('work_types.minutes')),

                        Infolists\Components\TextEntry::make('status')
                            ->label(__('extensions.fields.status'))
                            ->badge()
                            ->formatStateUsing(fn (ExtensionStatus $state) => $state->label())
                            ->color(fn (ExtensionStatus $state) => $state->color())
                            ->icon(fn (ExtensionStatus $state) => $state->icon()),

                        Infolists\Components\TextEntry::make('requester.name')
                            ->label(__('extensions.fields.requested_by')),

                        Infolists\Components\TextEntry::make('requested_at')
                            ->label(__('extensions.fields.requested_at'))
                            ->dateTime(),
                    ])
                    ->columns(2),

                Section::make(__('extensions.reason'))
                    ->schema([
                        Infolists\Components\TextEntry::make('reason')
                            ->label(__('extensions.fields.reason'))
                            ->columnSpanFull(),
                    ]),

                Section::make(__('extensions.admin_response'))
                    ->schema([
                        Infolists\Components\TextEntry::make('responder.name')
                            ->label(__('extensions.fields.responded_by'))
                            ->default('-'),

                        Infolists\Components\TextEntry::make('responded_at')
                            ->label(__('extensions.fields.responded_at'))
                            ->dateTime()
                            ->default('-'),

                        Infolists\Components\TextEntry::make('admin_notes')
                            ->label(__('extensions.fields.admin_notes'))
                            ->default('-')
                            ->columnSpanFull(),
                    ])
                    ->columns(2)
                    ->visible(fn (TimeExtensionRequest $record): bool => ! $record->isPending()),

                Section::make(__('extensions.slot_impact'))
                    ->schema([
                        Infolists\Components\TextEntry::make('assignment.assigned_start_time')
                            ->label(__('extensions.fields.start_time')),

                        Infolists\Components\TextEntry::make('assignment.assigned_end_time')
                            ->label(__('extensions.fields.end_time'))
                            ->color('success'),

                        Infolists\Components\TextEntry::make('assignment.allocated_duration_minutes')
                            ->label(__('extensions.fields.allocated_duration'))
                            ->formatStateUsing(fn ($state) => $state ? $state.' '.__('work_types.minutes') : '-'),

                        Infolists\Components\TextEntry::make('assignment.scheduled_date')
                            ->label(__('extensions.fields.scheduled_date'))
                            ->date(),
                    ])
                    ->columns(2)
                    ->visible(fn (TimeExtensionRequest $record): bool => $record->isApproved()),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListTimeExtensionRequests::route('/'),
            'view' => Pages\ViewTimeExtensionRequest::route('/{record}'),
        ];
    }
}
