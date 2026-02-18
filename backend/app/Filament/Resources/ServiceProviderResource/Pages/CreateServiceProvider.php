<?php



namespace App\Filament\Resources\ServiceProviderResource\Pages;

use App\Enums\UserRole;
use App\Filament\Resources\ServiceProviderResource;
use App\Models\User;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Hash;

class CreateServiceProvider extends CreateRecord
{
    protected static string $resource = ServiceProviderResource::class;

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

        // Assign service provider role
        $user->assignRole(UserRole::SERVICE_PROVIDER->value);

        // Create service provider record
        $serviceProvider = $user->serviceProvider()->create([
            'is_available' => $data['is_available'] ?? true,
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
        ]);

        // Sync categories
        if (!empty($data['categories'])) {
            $serviceProvider->categories()->sync($data['categories']);
        }

        // Create time slots if provided
        if (!empty($data['timeSlots'])) {
            foreach ($data['timeSlots'] as $slotData) {
                $serviceProvider->timeSlots()->create([
                    'day_of_week' => $slotData['day_of_week'],
                    'start_time' => $slotData['start_time'],
                    'end_time' => $slotData['end_time'],
                    'is_active' => $slotData['is_active'] ?? true,
                ]);
            }
        }

        return $serviceProvider;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
