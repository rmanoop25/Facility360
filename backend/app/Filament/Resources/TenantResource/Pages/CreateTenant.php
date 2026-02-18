<?php



namespace App\Filament\Resources\TenantResource\Pages;

use App\Enums\UserRole;
use App\Filament\Resources\TenantResource;
use App\Models\User;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Hash;

class CreateTenant extends CreateRecord
{
    protected static string $resource = TenantResource::class;

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }

    protected function handleRecordCreation(array $data): Model
    {
        // Create user first
        $user = User::create([
            'name' => $data['user']['name'],
            'email' => $data['user']['email'],
            'password' => Hash::make($data['user']['password']),
            'phone' => $data['user']['phone'] ?? null,
            'profile_photo' => $data['profile_photo'] ?? null,
            'is_active' => $data['user']['is_active'] ?? true,
        ]);

        // Assign tenant role
        $user->assignRole(UserRole::TENANT->value);

        // Create tenant record
        return $user->tenant()->create([
            'unit_number' => $data['unit_number'],
            'building_name' => $data['building_name'] ?? null,
        ]);
    }
}
