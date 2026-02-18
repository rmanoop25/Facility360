<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class UpdateTenantRequest extends FormRequest
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
        $tenant = $this->route('tenant');
        $userId = $tenant?->user_id ?? $tenant?->user?->id;

        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => [
                'required',
                'string',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($userId),
            ],
            'password' => ['nullable', 'string', Password::min(8)],
            'phone' => ['nullable', 'string', 'max:20'],
            'unit_number' => ['required', 'string', 'max:50'],
            'building_name' => ['nullable', 'string', 'max:255'],
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
            'name.required' => __('validation.custom.tenant.name_required'),
            'name.max' => __('validation.custom.tenant.name_max'),
            'email.required' => __('validation.custom.tenant.email_required'),
            'email.email' => __('validation.custom.tenant.email_invalid'),
            'email.unique' => __('validation.custom.tenant.email_taken'),
            'password.min' => __('validation.custom.tenant.password_min'),
            'unit_number.required' => __('validation.custom.tenant.unit_number_required'),
            'unit_number.max' => __('validation.custom.tenant.unit_number_max'),
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
            'name' => __('validation.attributes.name'),
            'email' => __('validation.attributes.email'),
            'password' => __('validation.attributes.password'),
            'phone' => __('validation.attributes.phone'),
            'unit_number' => __('validation.attributes.unit_number'),
            'building_name' => __('validation.attributes.building_name'),
        ];
    }
}
