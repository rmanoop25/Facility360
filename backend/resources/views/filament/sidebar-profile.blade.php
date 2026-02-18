@php
    $user = filament()->auth()->user();
@endphp

@if ($user)
<div class="fi-sidebar-footer-profile">
    <a href="{{ filament()->getProfileUrl() }}"
       style="display: flex; flex-direction: row; align-items: center; gap: 10px;">
        {{-- Small circular avatar --}}
        <img
            src="{{ filament()->getUserAvatarUrl($user) }}"
            alt="{{ $user->name }}"
            style="width: 32px; height: 32px; border-radius: 50%; object-fit: cover; flex-shrink: 0;"
        />
        {{-- Name & Email --}}
        <div class="fi-sidebar-profile-name" style="flex: 1; min-width: 0; line-height: 1.3;">
            <div class="text-sm font-semibold text-gray-900 dark:text-white truncate">
                {{ $user->name }}
            </div>
            <div class="text-xs text-gray-700 dark:text-gray-300 truncate">
                {{ $user->email }}
            </div>
        </div>
        {{-- Chevron --}}
        <x-filament::icon
            icon="heroicon-m-chevron-right"
            class="fi-sidebar-profile-icon h-4 w-4 text-gray-400"
            style="flex-shrink: 0;"
        />
    </a>
</div>
@endif
