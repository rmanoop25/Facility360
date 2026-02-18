<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AdminUserResource\Pages;
use App\Models\User;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteAction;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ViewAction;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Role;

class AdminUserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-users';

    protected static ?int $navigationSort = 0;

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.users');
    }

    public static function getModelLabel(): string
    {
        return __('admin_users.singular');
    }

    public static function getPluralModelLabel(): string
    {
        return __('admin_users.plural');
    }

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make(__('admin_users.sections.user_info'))
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->label(__('admin_users.fields.name'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('email')
                            ->label(__('admin_users.fields.email'))
                            ->email()
                            ->required()
                            ->unique(ignoreRecord: true)
                            ->maxLength(255),

                        Forms\Components\TextInput::make('password')
                            ->label(__('admin_users.fields.password'))
                            ->password()
                            ->revealable()
                            ->required(fn (string $operation): bool => $operation === 'create')
                            ->dehydrated(fn (?string $state): bool => filled($state))
                            ->dehydrateStateUsing(fn (string $state): string => Hash::make($state))
                            ->minLength(8)
                            ->maxLength(255)
                            ->visibleOn('create'),

                        Forms\Components\TextInput::make('phone')
                            ->label(__('admin_users.fields.phone'))
                            ->tel()
                            ->maxLength(20),
                    ])
                    ->columns(2),

                Section::make(__('admin_users.sections.role_status'))
                    ->schema([
                        Forms\Components\Select::make('role')
                            ->label(__('admin_users.fields.role'))
                            ->options(function () {
                                // Exclude mobile-only roles (tenant, service_provider)
                                return Role::whereNotIn('name', ['tenant', 'service_provider'])
                                    ->pluck('name', 'name')
                                    ->mapWithKeys(fn ($name) => [
                                        $name => __("admin_users.roles.{$name}", [], null) !== "admin_users.roles.{$name}"
                                            ? __("admin_users.roles.{$name}")
                                            : ucwords(str_replace('_', ' ', $name)),
                                    ]);
                            })
                            ->required()
                            ->native(false)
                            ->searchable(),

                        Forms\Components\Toggle::make('is_active')
                            ->label(__('admin_users.fields.is_active'))
                            ->default(true)
                            ->inline(false),
                    ])
                    ->columns(2),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label(__('admin_users.fields.name'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('email')
                    ->label(__('admin_users.fields.email'))
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->copyMessage(__('common.copied')),

                Tables\Columns\TextColumn::make('phone')
                    ->label(__('admin_users.fields.phone'))
                    ->searchable(),

                Tables\Columns\TextColumn::make('roles.name')
                    ->label(__('admin_users.fields.role'))
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => __("admin_users.roles.{$state}"))
                    ->color(fn (string $state): string => match ($state) {
                        'super_admin' => 'danger',
                        'manager' => 'warning',
                        'viewer' => 'info',
                        default => 'gray',
                    }),

                Tables\Columns\IconColumn::make('is_active')
                    ->label(__('admin_users.fields.is_active'))
                    ->boolean()
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('admin_users.fields.created_at'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('role')
                    ->label(__('admin_users.filters.role'))
                    ->options(function () {
                        // Exclude mobile-only roles (tenant, service_provider)
                        return Role::whereNotIn('name', ['tenant', 'service_provider'])
                            ->pluck('name', 'name')
                            ->mapWithKeys(fn ($name) => [
                                $name => __("admin_users.roles.{$name}", [], null) !== "admin_users.roles.{$name}"
                                    ? __("admin_users.roles.{$name}")
                                    : ucwords(str_replace('_', ' ', $name)),
                            ]);
                    })
                    ->query(function (Builder $query, array $data): Builder {
                        if (filled($data['value'])) {
                            return $query->whereHas('roles', fn ($q) => $q->where('name', $data['value']));
                        }

                        return $query;
                    }),

                Tables\Filters\TernaryFilter::make('is_active')
                    ->label(__('admin_users.filters.active')),
            ])
            ->actions([
                ViewAction::make()
                    ->visible(fn ($record) => auth()->user()->can('view', $record)),
                EditAction::make()
                    ->visible(fn ($record) => auth()->user()->can('update', $record)),

                Action::make('reset_password')
                    ->authorize('update')
                    ->icon('heroicon-o-key')
                    ->color('warning')
                    ->iconButton()
                    ->tooltip(__('admin_users.actions.reset_password'))
                    ->requiresConfirmation()
                    ->modalHeading(__('admin_users.actions.reset_password'))
                    ->modalDescription(__('admin_users.actions.reset_password_confirmation'))
                    ->form([
                        Forms\Components\TextInput::make('new_password')
                            ->label(__('admin_users.fields.new_password'))
                            ->password()
                            ->revealable()
                            ->required()
                            ->minLength(8)
                            ->confirmed(),

                        Forms\Components\TextInput::make('new_password_confirmation')
                            ->label(__('admin_users.fields.confirm_password'))
                            ->password()
                            ->revealable()
                            ->required(),
                    ])
                    ->action(function (User $record, array $data): void {
                        $record->update([
                            'password' => Hash::make($data['new_password']),
                        ]);
                    }),

                Action::make('toggle_active')
                    ->authorize('update')
                    ->icon(fn (User $record) => $record->is_active
                        ? 'heroicon-o-x-circle'
                        : 'heroicon-o-check-circle')
                    ->color(fn (User $record) => $record->is_active ? 'danger' : 'success')
                    ->iconButton()
                    ->tooltip(fn (User $record) => $record->is_active
                        ? __('admin_users.actions.deactivate')
                        : __('admin_users.actions.activate'))
                    ->requiresConfirmation()
                    ->hidden(fn (User $record) => $record->id === auth()->id())
                    ->action(fn (User $record) => $record->update([
                        'is_active' => ! $record->is_active,
                    ])),

                DeleteAction::make()
                    ->hidden(fn (User $record) => $record->id === auth()->id()),
            ])
            ->bulkActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),

                    BulkAction::make('activate')
                        ->label(__('admin_users.actions.activate'))
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->requiresConfirmation()
                        ->action(fn ($records) => $records->each(
                            fn (User $record) => $record->update(['is_active' => true])
                        )),

                    BulkAction::make('deactivate')
                        ->label(__('admin_users.actions.deactivate'))
                        ->icon('heroicon-o-x-circle')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->action(fn ($records) => $records->each(
                            fn (User $record) => $record->id !== auth()->id()
                                ? $record->update(['is_active' => false])
                                : null
                        )),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make(__('admin_users.sections.user_info'))
                    ->schema([
                        \Filament\Infolists\Components\TextEntry::make('name')
                            ->label(__('admin_users.fields.name')),

                        \Filament\Infolists\Components\TextEntry::make('email')
                            ->label(__('admin_users.fields.email'))
                            ->copyable(),

                        \Filament\Infolists\Components\TextEntry::make('phone')
                            ->label(__('admin_users.fields.phone')),
                    ])
                    ->columns(3),

                Section::make(__('admin_users.sections.role_status'))
                    ->schema([
                        \Filament\Infolists\Components\TextEntry::make('roles.name')
                            ->label(__('admin_users.fields.role'))
                            ->badge()
                            ->formatStateUsing(fn (string $state): string => __("admin_users.roles.{$state}"))
                            ->color(fn (string $state): string => match ($state) {
                                'super_admin' => 'danger',
                                'manager' => 'warning',
                                'viewer' => 'info',
                                default => 'gray',
                            }),

                        \Filament\Infolists\Components\IconEntry::make('is_active')
                            ->label(__('admin_users.fields.is_active'))
                            ->boolean(),

                        \Filament\Infolists\Components\TextEntry::make('created_at')
                            ->label(__('admin_users.fields.created_at'))
                            ->dateTime(),

                        \Filament\Infolists\Components\TextEntry::make('updated_at')
                            ->label(__('admin_users.fields.updated_at'))
                            ->dateTime(),
                    ])
                    ->columns(4),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListAdminUsers::route('/'),
            'create' => Pages\CreateAdminUser::route('/create'),
            'view' => Pages\ViewAdminUser::route('/{record}'),
            'edit' => Pages\EditAdminUser::route('/{record}/edit'),
        ];
    }

    public static function getEloquentQuery(): Builder
    {
        // Show all users except mobile-only roles (tenant, service_provider)
        return parent::getEloquentQuery()
            ->whereHas('roles', fn ($q) => $q->whereNotIn('name', ['tenant', 'service_provider']));
    }
}
