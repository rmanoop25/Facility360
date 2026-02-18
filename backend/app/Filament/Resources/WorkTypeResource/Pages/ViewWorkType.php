<?php

namespace App\Filament\Resources\WorkTypeResource\Pages;

use App\Filament\Resources\WorkTypeResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

class ViewWorkType extends ViewRecord
{
    protected static string $resource = WorkTypeResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
        ];
    }
}
