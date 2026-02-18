<?php

namespace App\Filament\Resources;

use App\Filament\Resources\TenantResource\Pages;
use App\Models\Tenant;
use App\Models\User;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Hash;

class TenantResource extends Resource
{
    protected static ?string $model = Tenant::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-user-group';

    protected static ?int $navigationSort = 1;

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.users');
    }

    public static function getModelLabel(): string
    {
        return __('tenants.singular');
    }

    public static function getPluralModelLabel(): string
    {
        return __('tenants.plural');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make(__('tenants.sections.personal_info'))
                    ->schema([
                        Grid::make(3)
                            ->schema([
                                Forms\Components\FileUpload::make('profile_photo')
                                    ->label(__('tenants.fields.profile_photo'))
                                    ->image()
                                    ->avatar()
                                    ->directory('profile-photos')
                                    ->maxSize(2048)
                                    ->imageResizeMode('cover')
                                    ->imageCropAspectRatio('1:1')
                                    ->imageResizeTargetWidth('200')
                                    ->imageResizeTargetHeight('200')
                                    ->columnSpan(1),

                                Grid::make(2)
                                    ->schema([
                                        Forms\Components\TextInput::make('user.name')
                                            ->label(__('tenants.fields.name'))
                                            ->required()
                                            ->maxLength(255),

                                        Forms\Components\TextInput::make('user.email')
                                            ->label(__('tenants.fields.email'))
                                            ->email()
                                            ->required()
                                            ->unique(
                                                table: User::class,
                                                column: 'email',
                                                ignorable: fn ($record) => $record?->user
                                            )
                                            ->maxLength(255),

                                        Forms\Components\TextInput::make('user.password')
                                            ->label(__('tenants.fields.password'))
                                            ->password()
                                            ->revealable()
                                            ->required(fn (string $operation): bool => $operation === 'create')
                                            ->dehydrated(fn (?string $state): bool => filled($state))
                                            ->minLength(8)
                                            ->maxLength(255)
                                            ->visibleOn('create'),

                                        Forms\Components\TextInput::make('user.phone')
                                            ->label(__('tenants.fields.phone'))
                                            ->tel()
                                            ->maxLength(20),
                                    ])
                                    ->columnSpan(2),
                            ]),
                    ]),

                Section::make(__('tenants.sections.address'))
                    ->schema([
                        Forms\Components\TextInput::make('unit_number')
                            ->label(__('tenants.fields.unit_number'))
                            ->required()
                            ->maxLength(50),

                        Forms\Components\TextInput::make('building_name')
                            ->label(__('tenants.fields.building_name'))
                            ->maxLength(255),
                    ])
                    ->columns(2),

                Section::make(__('tenants.sections.status'))
                    ->schema([
                        Forms\Components\Toggle::make('user.is_active')
                            ->label(__('tenants.fields.is_active'))
                            ->default(true)
                            ->inline(false),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('user.name')
                    ->label(__('tenants.fields.name'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.email')
                    ->label(__('tenants.fields.email'))
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->copyMessage(__('common.copied')),

                Tables\Columns\TextColumn::make('user.phone')
                    ->label(__('tenants.fields.phone'))
                    ->searchable(),

                Tables\Columns\TextColumn::make('unit_number')
                    ->label(__('tenants.fields.unit_number'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('building_name')
                    ->label(__('tenants.fields.building_name'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('issues_count')
                    ->label(__('tenants.fields.issues_count'))
                    ->counts('issues')
                    ->sortable()
                    ->badge()
                    ->color('primary'),

                Tables\Columns\IconColumn::make('user.is_active')
                    ->label(__('tenants.fields.is_active'))
                    ->boolean()
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('common.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\TernaryFilter::make('user.is_active')
                    ->label(__('tenants.filters.active'))
                    ->queries(
                        true: fn (Builder $query) => $query->whereHas('user', fn ($q) => $q->where('is_active', true)),
                        false: fn (Builder $query) => $query->whereHas('user', fn ($q) => $q->where('is_active', false)),
                    ),

                Tables\Filters\Filter::make('has_issues')
                    ->label(__('tenants.filters.has_issues'))
                    ->query(fn (Builder $query) => $query->has('issues')),
            ])
            ->actions([
                EditAction::make()
                    ->visible(fn ($record) => auth()->user()->can('update', $record)),

                Action::make('reset_password')
                    ->authorize('resetPassword')
                    ->icon('heroicon-o-key')
                    ->color('warning')
                    ->iconButton()
                    ->tooltip(__('tenants.actions.reset_password'))
                    ->requiresConfirmation()
                    ->modalHeading(__('tenants.actions.reset_password'))
                    ->modalDescription(__('tenants.actions.reset_password_confirmation'))
                    ->form([
                        Forms\Components\TextInput::make('new_password')
                            ->label(__('tenants.fields.new_password'))
                            ->password()
                            ->revealable()
                            ->required()
                            ->minLength(8)
                            ->confirmed(),

                        Forms\Components\TextInput::make('new_password_confirmation')
                            ->label(__('tenants.fields.confirm_password'))
                            ->password()
                            ->revealable()
                            ->required(),
                    ])
                    ->action(function (Tenant $record, array $data): void {
                        $record->user->update([
                            'password' => Hash::make($data['new_password']),
                        ]);
                    }),

                DeleteAction::make()
                    ->visible(fn ($record) => auth()->user()->can('delete', $record)),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),

                    BulkAction::make('activate')
                        ->label(__('tenants.actions.activate'))
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->requiresConfirmation()
                        ->action(function ($records): void {
                            if (! auth()->user()->can('Update:Tenant')) {
                                Notification::make()
                                    ->danger()
                                    ->title(__('filament-actions::delete.multiple.messages.unauthorized'))
                                    ->send();

                                return;
                            }

                            $records->each(fn (Tenant $record) => $record->user->update(['is_active' => true]));
                        }),

                    BulkAction::make('deactivate')
                        ->label(__('tenants.actions.deactivate'))
                        ->icon('heroicon-o-x-circle')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->action(function ($records): void {
                            if (! auth()->user()->can('Update:Tenant')) {
                                Notification::make()
                                    ->danger()
                                    ->title(__('filament-actions::delete.multiple.messages.unauthorized'))
                                    ->send();

                                return;
                            }

                            $records->each(fn (Tenant $record) => $record->user->update(['is_active' => false]));
                        }),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListTenants::route('/'),
            'create' => Pages\CreateTenant::route('/create'),
            'edit' => Pages\EditTenant::route('/{record}/edit'),
        ];
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->with(['user']);
    }
}
