<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\Admin;

use Illuminate\Foundation\Http\FormRequest;

class StoreConsumableRequest extends FormRequest
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
            'category_id' => ['required', 'integer', 'exists:categories,id'],
            'name_en' => ['required', 'string', 'max:255'],
            'name_ar' => ['required', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
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
            'category_id.required' => __('validation.custom.consumable.category_required'),
            'category_id.exists' => __('validation.custom.consumable.category_invalid'),
            'name_en.required' => __('validation.custom.consumable.name_en_required'),
            'name_en.max' => __('validation.custom.consumable.name_en_max'),
            'name_ar.required' => __('validation.custom.consumable.name_ar_required'),
            'name_ar.max' => __('validation.custom.consumable.name_ar_max'),
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
            'category_id' => __('validation.attributes.category'),
            'name_en' => __('validation.attributes.name_en'),
            'name_ar' => __('validation.attributes.name_ar'),
            'is_active' => __('validation.attributes.is_active'),
        ];
    }

    /**
     * Prepare the data for validation.
     */
    protected function prepareForValidation(): void
    {
        if (!$this->has('is_active')) {
            $this->merge(['is_active' => true]);
        }
    }
}
