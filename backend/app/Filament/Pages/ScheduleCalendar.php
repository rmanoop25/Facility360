<?php

declare(strict_types=1);

namespace App\Filament\Pages;

use App\Enums\AssignmentStatus;
use App\Enums\IssueStatus;
use App\Models\Category;
use App\Models\Issue;
use App\Models\IssueAssignment;
use App\Models\ServiceProvider;
use BackedEnum;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Form;
use Filament\Pages\Page;
use Illuminate\Database\Eloquent\Builder;
use Saade\FilamentFullCalendar\Actions\ViewAction;
use Saade\FilamentFullCalendar\Widgets\FullCalendarWidget;

class ScheduleCalendar extends Page
{
    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-calendar-days';

    protected string $view = 'filament.pages.schedule-calendar';

    protected static ?int $navigationSort = 2;

    public static function getNavigationGroup(): ?string
    {
        return __('navigation.issues');
    }

    public static function canAccess(): bool
    {
        return auth()->check();
    }

    public static function getNavigationLabel(): string
    {
        return __('calendar.navigation_label');
    }

    public function getTitle(): string
    {
        return __('calendar.title');
    }

    public function getSubheading(): ?string
    {
        return __('calendar.subheading');
    }
}
