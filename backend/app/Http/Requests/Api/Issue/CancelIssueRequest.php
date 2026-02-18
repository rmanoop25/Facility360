<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\Issue;

use Illuminate\Foundation\Http\FormRequest;

class CancelIssueRequest extends FormRequest
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
            'reason' => ['required', 'string', 'min:10', 'max:1000'],
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
            'reason.required' => __('validation.custom.issue.cancel_reason_required'),
            'reason.min' => __('validation.custom.issue.cancel_reason_min'),
            'reason.max' => __('validation.custom.issue.cancel_reason_max'),
        ];
    }
}
