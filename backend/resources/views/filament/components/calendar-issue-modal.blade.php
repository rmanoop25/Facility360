<div class="fi-modal-content space-y-4">
    {{-- Basic Info Section --}}
    <x-filament::section>
        <x-slot name="heading">
            {{ __('issues.sections.basic_info') }}
        </x-slot>

        <dl class="fi-in-simple grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.id') }}
                </dt>
                <dd class="fi-in-entry-wrp-content text-sm leading-6 text-gray-500 dark:text-gray-400">
                    #{{ $issue->id }}
                </dd>
            </div>

            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.title') }}
                </dt>
                <dd class="fi-in-entry-wrp-content text-sm leading-6 text-gray-500 dark:text-gray-400">
                    {{ $issue->title }}
                </dd>
            </div>

            <div class="fi-in-entry-wrp sm:col-span-2">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.description') }}
                </dt>
                <dd class="fi-in-entry-wrp-content text-sm leading-6 text-gray-500 dark:text-gray-400">
                    {{ $issue->description }}
                </dd>
            </div>

            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.tenant') }}
                </dt>
                <dd class="fi-in-entry-wrp-content text-sm leading-6 text-gray-500 dark:text-gray-400">
                    {{ $issue->tenant->user->name }}
                </dd>
            </div>

            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.address') }}
                </dt>
                <dd class="fi-in-entry-wrp-content text-sm leading-6 text-gray-500 dark:text-gray-400">
                    {{ $issue->tenant->full_address }}
                </dd>
            </div>
        </dl>
    </x-filament::section>

    {{-- Status & Priority Section --}}
    <x-filament::section>
        <x-slot name="heading">
            {{ __('issues.sections.priority_status') }}
        </x-slot>

        <dl class="fi-in-simple grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.status') }}
                </dt>
                <dd class="fi-in-entry-wrp-content mt-1">
                    <x-filament::badge :color="$issue->status->color()">
                        {{ $issue->status->label() }}
                    </x-filament::badge>
                </dd>
            </div>

            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.priority') }}
                </dt>
                <dd class="fi-in-entry-wrp-content mt-1">
                    <x-filament::badge :color="$issue->priority->color()">
                        {{ $issue->priority->label() }}
                    </x-filament::badge>
                </dd>
            </div>

            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.categories') }}
                </dt>
                <dd class="fi-in-entry-wrp-content mt-1 flex flex-wrap gap-1">
                    @foreach($issue->categories as $category)
                        <x-filament::badge color="info">
                            {{ $category->localizedName }}
                        </x-filament::badge>
                    @endforeach
                </dd>
            </div>

            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.proof_required') }}
                </dt>
                <dd class="fi-in-entry-wrp-content mt-1">
                    @if($issue->proof_required)
                        <x-filament::badge color="success">
                            {{ __('common.yes') }}
                        </x-filament::badge>
                    @else
                        <x-filament::badge color="gray">
                            {{ __('common.no') }}
                        </x-filament::badge>
                    @endif
                </dd>
            </div>
        </dl>
    </x-filament::section>

    {{-- Assignments Section --}}
    <x-filament::section :collapsible="true">
        <x-slot name="heading">
            {{ __('issues.sections.assignments') }}
        </x-slot>

        @if($issue->assignments->isEmpty())
            <p class="text-sm text-gray-500 dark:text-gray-400">{{ __('issues.no_assignments') }}</p>
        @else
            <div class="space-y-3">
                @foreach($issue->assignments as $assignment)
                    <div class="rounded-lg border border-gray-200 p-3 dark:border-gray-700">
                        <div class="flex items-center justify-between">
                            <span class="text-sm font-medium text-gray-950 dark:text-white">
                                {{ $assignment->serviceProvider->user->name }}
                            </span>
                            <x-filament::badge :color="$assignment->status->color()">
                                {{ $assignment->status->label() }}
                            </x-filament::badge>
                        </div>
                        <div class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                            {{ $assignment->category?->localizedName ?? __('common.n_a') }} |
                            {{ $assignment->scheduled_date?->format('Y-m-d') ?? __('common.not_scheduled') }} |
                            {{ $assignment->timeSlot?->display_name ?? __('common.n_a') }}
                        </div>
                    </div>
                @endforeach
            </div>
        @endif
    </x-filament::section>

    {{-- Metadata Section --}}
    <x-filament::section :collapsible="true" :collapsed="true">
        <x-slot name="heading">
            {{ __('issues.sections.metadata') }}
        </x-slot>

        <dl class="fi-in-simple grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.created_at') }}
                </dt>
                <dd class="fi-in-entry-wrp-content text-sm leading-6 text-gray-500 dark:text-gray-400">
                    {{ $issue->created_at->format('Y-m-d H:i:s') }}
                </dd>
            </div>

            <div class="fi-in-entry-wrp">
                <dt class="fi-in-entry-wrp-label text-sm font-medium leading-6 text-gray-950 dark:text-white">
                    {{ __('issues.fields.updated_at') }}
                </dt>
                <dd class="fi-in-entry-wrp-content text-sm leading-6 text-gray-500 dark:text-gray-400">
                    {{ $issue->updated_at->format('Y-m-d H:i:s') }}
                </dd>
            </div>
        </dl>
    </x-filament::section>
</div>
