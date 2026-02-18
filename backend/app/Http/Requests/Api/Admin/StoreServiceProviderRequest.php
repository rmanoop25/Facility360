<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class StoreServiceProviderRequest extends FormRequest
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
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', Password::min(8)],
            'phone' => ['nullable', 'string', 'max:20'],
            'category_id' => ['required', 'integer', 'exists:categories,id'],
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
            'name.required' => __('validation.custom.service_provider.name_required'),
            'name.max' => __('validation.custom.service_provider.name_max'),
            'email.required' => __('validation.custom.service_provider.email_required'),
            'email.email' => __('validation.custom.service_provider.email_invalid'),
            'email.unique' => __('validation.custom.service_provider.email_taken'),
            'password.required' => __('validation.custom.service_provider.password_required'),
            'password.min' => __('validation.custom.service_provider.password_min'),
            'category_id.required' => __('validation.custom.service_provider.category_required'),
            'category_id.exists' => __('validation.custom.service_provider.category_invalid'),
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
            'category_id' => __('validation.attributes.category'),
        ];
    }
}
