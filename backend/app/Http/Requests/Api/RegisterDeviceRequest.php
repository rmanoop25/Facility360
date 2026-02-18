<?php

declare(strict_types=1);

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RegisterDeviceRequest extends FormRequest
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
            'fcm_token' => ['required', 'string', 'max:500'],
            'device_type' => ['nullable', 'string', Rule::in(['ios', 'android', 'web'])],
            'device_name' => ['nullable', 'string', 'max:255'],
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
            'fcm_token.required' => __('validation.custom.device.fcm_token_required'),
            'fcm_token.max' => __('validation.custom.device.fcm_token_max'),
            'device_type.in' => __('validation.custom.device.device_type_invalid'),
        ];
    }
}
