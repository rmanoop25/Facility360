<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\TimeExtensionRequest;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class PendingExtensionsWidget extends BaseWidget
{
    protected static ?int $sort = 2;

    protected function getStats(): array
    {
        $pending = TimeExtensionRequest::pending()->count();

        return [
            Stat::make(__('extensions.widget.pending'), $pending)
                ->description(__('extensions.widget.pending_description'))
                ->icon('heroicon-o-clock')
                ->color($pending > 0 ? 'warning' : 'success')
                ->url(route('filament.admin.resources.time-extension-requests.index', [
                    'tableFilters[status][value]' => 'pending',
                ])),
        ];
    }

    public static function canView(): bool
    {
        return auth()->user()?->can('view_time_extensions') ?? false;
    }
}
