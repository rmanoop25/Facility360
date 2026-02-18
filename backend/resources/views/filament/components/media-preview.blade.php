@props(['media' => []])

@if(count($media) > 0)
    {{-- Audio items are full-width; photos/videos/PDFs go in a responsive grid --}}
    @php
        $audioItems = collect($media)->filter(fn($i) => ($i->type ?? \App\Enums\MediaType::PHOTO) === \App\Enums\MediaType::AUDIO);
        $gridItems  = collect($media)->filter(fn($i) => ($i->type ?? \App\Enums\MediaType::PHOTO) !== \App\Enums\MediaType::AUDIO);
    @endphp

    {{-- Full-width audio players --}}
    @foreach($audioItems as $item)
        @php $url = $item->url ?? $item->path ?? null; @endphp
        <div class="mb-3 flex items-center gap-3 rounded-lg border border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-800">
            {{-- Icon --}}
            <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-indigo-100 dark:bg-indigo-900/40">
                <svg class="h-5 w-5 text-indigo-600 dark:text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
                </svg>
            </div>
            {{-- Player --}}
            <audio controls preload="metadata" class="h-10 min-w-0 flex-1">
                <source src="{{ $url }}" type="audio/mpeg">
            </audio>
            {{-- Download --}}
            @if($url)
                <a href="{{ $url }}" download
                   class="shrink-0 rounded-full bg-white p-1.5 shadow-sm hover:bg-gray-100 dark:bg-gray-700 dark:hover:bg-gray-600 transition"
                   title="{{ __('common.download') }}">
                    <svg class="h-4 w-4 text-gray-700 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                    </svg>
                </a>
            @endif
        </div>
    @endforeach

    {{-- Grid for photos, videos, PDFs --}}
    @if($gridItems->isNotEmpty())
    <div class="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
        @foreach($gridItems as $item)
            <div class="relative overflow-hidden rounded-lg border border-gray-200 dark:border-gray-700">
                @php
                    $type = $item->type ?? \App\Enums\MediaType::PHOTO;
                    $url = $item->url ?? $item->path ?? null;
                @endphp

                @if($type === \App\Enums\MediaType::PHOTO)
                    {{-- Photo: Display image --}}
                    <img
                        src="{{ $url }}"
                        alt="Issue photo"
                        class="h-32 w-full object-cover cursor-pointer hover:opacity-90 transition"
                        onclick="window.open('{{ $url }}', '_blank')"
                    />
                @elseif($type === \App\Enums\MediaType::VIDEO)
                    {{-- Video: Display player --}}
                    <video
                        controls
                        class="h-32 w-full object-cover bg-black"
                        preload="metadata"
                    >
                        <source src="{{ $url }}" type="video/mp4">
                        Your browser does not support the video tag.
                    </video>
                @elseif($type === \App\Enums\MediaType::PDF)
                    {{-- PDF: Display icon with download link --}}
                    <a
                        href="{{ $url }}"
                        target="_blank"
                        class="flex h-32 flex-col items-center justify-center bg-red-50 dark:bg-red-900/20 hover:bg-red-100 dark:hover:bg-red-900/30 transition"
                    >
                        <svg class="h-12 w-12 text-red-600 dark:text-red-400" fill="currentColor" viewBox="0 0 24 24">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6z"></path>
                            <path fill="#fff" d="M14 2v6h6"></path>
                            <text x="50%" y="65%" text-anchor="middle" fill="#fff" font-size="6" font-weight="bold">PDF</text>
                        </svg>
                        <span class="mt-2 text-xs font-medium text-red-600 dark:text-red-400">{{ __('common.view_pdf') }}</span>
                    </a>
                @endif

                {{-- Download button overlay --}}
                @if($url)
                    <div class="absolute top-2 right-2">
                        <a
                            href="{{ $url }}"
                            download
                            class="rounded-full bg-white/90 dark:bg-gray-800/90 p-1.5 shadow-md hover:bg-white dark:hover:bg-gray-800 transition"
                            title="{{ __('common.download') }}"
                        >
                            <svg class="h-4 w-4 text-gray-700 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                            </svg>
                        </a>
                    </div>
                @endif
            </div>
        @endforeach
    </div>
    @endif
@else
    <div class="text-sm text-gray-500 dark:text-gray-400">
        {{ __('issues.no_media_attached') }}
    </div>
@endif
