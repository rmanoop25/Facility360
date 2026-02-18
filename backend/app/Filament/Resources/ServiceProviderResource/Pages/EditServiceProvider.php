<?php



namespace App\Filament\Resources\ServiceProviderResource\Pages;

use App\Filament\Resources\ServiceProviderResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Database\Eloquent\Model;

class EditServiceProvider extends EditRecord
{
    protected static string $resource = ServiceProviderResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            Actions\DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeFill(array $data): array
    {
        $data['user'] = $this->record->user->toArray();
        $data['profile_photo'] = $this->record->user->profile_photo;

        // Load time slots with computed is_full_day
        $data['timeSlots'] = $this->record->timeSlots->map(function ($slot) {
            $startTime = $slot->start_time?->format('H:i') ?? $slot->start_time;
            $endTime = $slot->end_time?->format('H:i') ?? $slot->end_time;

            return [
                'id' => $slot->id,
                'day_of_week' => $slot->day_of_week,
                'start_time' => $startTime,
                'end_time' => $endTime,
                'is_active' => $slot->is_active,
                'is_full_day' => $startTime === '00:00' && $endTime === '23:59',
            ];
        })->toArray();

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

        // Update service provider data
        $record->update([
            'is_available' => $data['is_available'] ?? true,
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
        ]);

        // Sync categories
        if (isset($data['categories'])) {
            $record->categories()->sync($data['categories']);
        }

        // Sync time slots
        $this->syncTimeSlots($record, $data['timeSlots'] ?? []);

        return $record;
    }

    protected function syncTimeSlots(Model $record, array $timeSlots): void
    {
        $existingIds = $record->timeSlots->pluck('id')->toArray();
        $updatedIds = [];

        foreach ($timeSlots as $slotData) {
            $slotAttributes = [
                'day_of_week' => $slotData['day_of_week'],
                'start_time' => $slotData['start_time'],
                'end_time' => $slotData['end_time'],
                'is_active' => $slotData['is_active'] ?? true,
            ];

            if (!empty($slotData['id'])) {
                // Update existing slot
                $record->timeSlots()->where('id', $slotData['id'])->update($slotAttributes);
                $updatedIds[] = $slotData['id'];
            } else {
                // Create new slot
                $newSlot = $record->timeSlots()->create($slotAttributes);
                $updatedIds[] = $newSlot->id;
            }
        }

        // Delete removed slots
        $slotsToDelete = array_diff($existingIds, $updatedIds);
        if (!empty($slotsToDelete)) {
            $record->timeSlots()->whereIn('id', $slotsToDelete)->delete();
        }
    }
}
