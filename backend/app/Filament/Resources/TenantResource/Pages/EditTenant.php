<?php



namespace App\Filament\Resources\TenantResource\Pages;

use App\Filament\Resources\TenantResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Database\Eloquent\Model;

class EditTenant extends EditRecord
{
    protected static string $resource = TenantResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeFill(array $data): array
    {
        $data['user'] = $this->record->user->toArray();
        // Set profile_photo at root level for FileUpload component
        $data['profile_photo'] = $this->record->user->profile_photo;

        return $data;
    }

    protected function handleRecordUpdate(Model $record, array $data): Model
    {
        // Update user data
        $userData = [
            'name' => $data['user']['name'],
            'email' => $data['user']['email'],
            'phone' => $data['user']['phone'] ?? null,
            'profile_photo' => $data['profile_photo'] ?? $record->user->profile_photo,
            'is_active' => $data['user']['is_active'] ?? true,
        ];

        $record->user->update($userData);

        // Update tenant data
        $record->update([
            'unit_number' => $data['unit_number'],
            'building_name' => $data['building_name'] ?? null,
        ]);

        return $record;
    }
}
