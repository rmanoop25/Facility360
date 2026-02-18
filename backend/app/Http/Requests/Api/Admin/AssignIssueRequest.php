<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\Admin;

use Illuminate\Foundation\Http\FormRequest;

class AssignIssueRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'service_provider_id' => ['required', 'integer', 'exists:service_providers,id'],
            'work_type_id' => ['nullable', 'integer', 'exists:work_types,id'],
            'allocated_duration_minutes' => ['nullable', 'integer', 'min:15', 'max:43200'], // Max 30 days
            'is_custom_duration' => ['nullable', 'boolean'],
            'scheduled_date' => ['required', 'date', 'after_or_equal:today'],
            'scheduled_end_date' => ['nullable', 'date', 'after_or_equal:scheduled_date'],
            'time_slot_id' => ['nullable', 'integer', 'exists:time_slots,id'],
            'time_slot_ids' => ['nullable', 'array'],
            'time_slot_ids.*' => ['integer', 'exists:time_slots,id'],
            'assigned_start_time' => ['nullable', 'string', 'regex:/^\d{2}:\d{2}$/'],
            'assigned_end_time' => ['nullable', 'string', 'regex:/^\d{2}:\d{2}$/'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }

    /**
     * Get custom messages for validator errors.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'service_provider_id.required' => __('validation.custom.assignment.service_provider_required'),
            'service_provider_id.exists' => __('validation.custom.assignment.service_provider_invalid'),
            'scheduled_date.required' => __('validation.custom.assignment.scheduled_date_required'),
            'scheduled_date.date' => __('validation.custom.assignment.scheduled_date_invalid'),
            'scheduled_date.after_or_equal' => __('validation.custom.assignment.scheduled_date_past'),
            'scheduled_end_date.after_or_equal' => 'End date must be on or after the start date',
            'time_slot_id.exists' => __('validation.custom.assignment.time_slot_invalid'),
            'time_slot_ids.*.exists' => 'One or more selected time slots are invalid',
            'allocated_duration_minutes.min' => 'Duration must be at least 15 minutes',
            'allocated_duration_minutes.max' => 'Duration cannot exceed 30 days (43,200 minutes)',
            'assigned_start_time.regex' => 'Start time must be in HH:MM format',
            'assigned_end_time.regex' => 'End time must be in HH:MM format',
        ];
    }

    /**
     * Get custom attributes for validator errors.
     *
     * @return array<string, string>
     */
    public function attributes(): array
    {
        return [
            'category_id' => 'category',
            'service_provider_id' => __('validation.attributes.service_provider'),
            'work_type_id' => 'work type',
            'allocated_duration_minutes' => 'duration',
            'scheduled_date' => __('validation.attributes.scheduled_date'),
            'scheduled_end_date' => 'end date',
            'time_slot_id' => __('validation.attributes.time_slot'),
            'time_slot_ids' => 'time slots',
            'assigned_start_time' => 'start time',
            'assigned_end_time' => 'end time',
        ];
    }
}
