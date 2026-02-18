<?php

declare(strict_types=1);

namespace App\Filament\Pages;

use App\Settings\IssueSettings;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Schemas\Components\Actions;
use Filament\Schemas\Components\EmbeddedSchema;
use Filament\Schemas\Components\Form;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class IssueSettingsPage extends Page implements HasForms
{
    use InteractsWithForms;

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-cog-6-tooth';

    protected static ?int $navigationSort = 100;

    protected string $view = 'filament.pages.issue-settings-page';

    public ?array $data = [];

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.settings');
    }

    public static function getNavigationLabel(): string
    {
        return __('settings.issue.navigation_label');
    }

    public function getTitle(): string
    {
        return __('settings.issue.title');
    }

    public function getSubheading(): ?string
    {
        return __('settings.issue.subheading');
    }

    public static function canAccess(): bool
    {
        return auth()->user()?->can('manage_settings') ?? false;
    }

    public function mount(): void
    {
        $settings = app(IssueSettings::class);
        $this->form->fill([
            'auto_approve_finished_issues' => $settings->auto_approve_finished_issues,
        ]);
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make(__('settings.issue.sections.approval'))
                    ->description(__('settings.issue.sections.approval_description'))
                    ->schema([
                        Toggle::make('auto_approve_finished_issues')
                            ->label(__('settings.issue.fields.auto_approve_finished_issues'))
                            ->helperText(__('settings.issue.fields.auto_approve_finished_issues_helper'))
                            ->inline(false)
                            ->default(false),
                    ]),
            ])
            ->statePath('data');
    }

    public function schema(Schema $schema): Schema
    {
        return $schema
            ->components([
                Form::make([
                    EmbeddedSchema::make('form'),
                ])
                    ->id('form')
                    ->livewireSubmitHandler('save')
                    ->footer([
                        Actions::make([
                            Action::make('save')
                                ->label(__('filament-panels::resources/pages/edit-record.form.actions.save.label'))
                                ->submit('form'),
                        ]),
                    ]),
            ]);
    }

    public function save(): void
    {
        $data = $this->form->getState();

        $settings = app(IssueSettings::class);
        $settings->auto_approve_finished_issues = $data['auto_approve_finished_issues'];
        $settings->save();

        Notification::make()
            ->success()
            ->title(__('settings.issue.messages.saved'))
            ->send();
    }
}
