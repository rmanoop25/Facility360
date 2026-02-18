<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\Issue;

use App\Enums\IssuePriority;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CreateIssueRequest extends FormRequest
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
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:5000'],
            'category_ids' => ['required', 'array', 'min:1'],
            'category_ids.*' => ['required', 'integer', 'exists:categories,id'],
            'priority' => ['required', 'string', Rule::enum(IssuePriority::class)],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'media' => ['nullable', 'array', 'max:10'],
            'media.*' => ['file', 'mimes:jpeg,jpg,png,gif,mp4,mov,avi', 'max:20480'],
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
            'title.required' => __('validation.custom.issue.title_required'),
            'title.max' => __('validation.custom.issue.title_max'),
            'category_ids.required' => __('validation.custom.issue.category_required'),
            'category_ids.min' => __('validation.custom.issue.category_min'),
            'category_ids.*.exists' => __('validation.custom.issue.category_invalid'),
            'priority.required' => __('validation.custom.issue.priority_required'),
            'priority.enum' => __('validation.custom.issue.priority_invalid'),
            'latitude.between' => __('validation.custom.issue.latitude_invalid'),
            'longitude.between' => __('validation.custom.issue.longitude_invalid'),
            'media.max' => __('validation.custom.issue.media_max_count'),
            'media.*.mimes' => __('validation.custom.issue.media_invalid_type'),
            'media.*.max' => __('validation.custom.issue.media_max_size'),
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
            'category_ids' => __('validation.attributes.categories'),
            'category_ids.*' => __('validation.attributes.category'),
            'media.*' => __('validation.attributes.media_file'),
        ];
    }
}
