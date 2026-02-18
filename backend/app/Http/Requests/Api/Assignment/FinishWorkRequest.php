<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\Assignment;

use Illuminate\Foundation\Http\FormRequest;

class FinishWorkRequest extends FormRequest
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
        $issue = $this->route('issue');
        $proofRequired = $issue?->proof_required ?? false;

        return [
            'consumables' => ['nullable', 'array'],
            'consumables.*.id' => ['required_with:consumables', 'integer', 'exists:consumables,id'],
            'consumables.*.quantity' => ['required_with:consumables', 'integer', 'min:1', 'max:9999'],

            'custom_consumables' => ['nullable', 'array'],
            'custom_consumables.*.name' => ['required_with:custom_consumables', 'string', 'max:255'],
            'custom_consumables.*.quantity' => ['required_with:custom_consumables', 'integer', 'min:1', 'max:9999'],
            'custom_consumables.*.unit' => ['nullable', 'string', 'max:50'],

            'notes' => ['nullable', 'string', 'max:2000'],

            'proofs' => [$proofRequired ? 'required' : 'nullable', 'array', 'max:10'],
            'proofs.*' => ['file', 'mimes:jpeg,jpg,png,gif,mp4,mov', 'max:20480'],
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
            'consumables.*.id.exists' => __('validation.custom.assignment.consumable_invalid'),
            'consumables.*.quantity.required_with' => __('validation.custom.assignment.consumable_quantity_required'),
            'consumables.*.quantity.min' => __('validation.custom.assignment.consumable_quantity_min'),

            'custom_consumables.*.name.required_with' => __('validation.custom.assignment.custom_consumable_name_required'),
            'custom_consumables.*.quantity.required_with' => __('validation.custom.assignment.custom_consumable_quantity_required'),

            'notes.max' => __('validation.custom.assignment.notes_max'),

            'proofs.required' => __('validation.custom.assignment.proofs_required'),
            'proofs.max' => __('validation.custom.assignment.proofs_max_count'),
            'proofs.*.mimes' => __('validation.custom.assignment.proofs_invalid_type'),
            'proofs.*.max' => __('validation.custom.assignment.proofs_max_size'),
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
            'consumables.*.id' => __('validation.attributes.consumable'),
            'consumables.*.quantity' => __('validation.attributes.quantity'),
            'custom_consumables.*.name' => __('validation.attributes.consumable_name'),
            'custom_consumables.*.quantity' => __('validation.attributes.quantity'),
            'proofs.*' => __('validation.attributes.proof_file'),
        ];
    }
}
