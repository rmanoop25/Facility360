@php
    $isRtl = app()->getLocale() === 'ar';
@endphp

<div class="login-page-wrapper">
    {{-- Include custom login styles --}}
    @include('filament.pages.auth.login-styles')

    <div class="login-container {{ $isRtl ? 'rtl' : 'ltr' }}">
        {{-- Branding Panel --}}
        <div class="login-branding-panel">
            <div class="branding-content">
                {{-- Animated Background Pattern --}}
                <div class="branding-pattern"></div>

                {{-- Logo & Brand --}}
                <div class="brand-logo">
                    <svg class="brand-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M11.42 15.17 17.25 21A2.652 2.652 0 0 0 21 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 1 1-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 0 0 4.486-6.336l-3.276 3.277a3.004 3.004 0 0 1-2.25-2.25l3.276-3.276a4.5 4.5 0 0 0-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437 1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008Z" />
                    </svg>
                    <h1 class="brand-name">{{ __('auth.brand_name') }}</h1>
                </div>

                {{-- Tagline --}}
                <p class="brand-tagline">{{ __('auth.brand_tagline') }}</p>

                {{-- Feature highlights --}}
                <div class="brand-features">
                    <div class="feature-item">
                        <svg class="feature-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                        </svg>
                        <span>{{ __('auth.feature_1') }}</span>
                    </div>
                    <div class="feature-item">
                        <svg class="feature-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                        </svg>
                        <span>{{ __('auth.feature_2') }}</span>
                    </div>
                    <div class="feature-item">
                        <svg class="feature-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
                        </svg>
                        <span>{{ __('auth.feature_3') }}</span>
                    </div>
                </div>
            </div>
        </div>

        {{-- Form Panel --}}
        <div class="login-form-panel">
            <div class="form-container">
                {{-- Language Switcher --}}
                <div class="language-switcher">
                    <a href="{{ request()->fullUrlWithQuery(['locale' => 'en']) }}"
                       class="{{ app()->getLocale() === 'en' ? 'active' : '' }}">EN</a>
                    <span class="divider">|</span>
                    <a href="{{ request()->fullUrlWithQuery(['locale' => 'ar']) }}"
                       class="{{ app()->getLocale() === 'ar' ? 'active' : '' }}">العربية</a>
                </div>

                {{-- Mobile Logo (hidden on desktop) --}}
                <div class="mobile-logo">
                    <svg class="mobile-brand-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M11.42 15.17 17.25 21A2.652 2.652 0 0 0 21 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 1 1-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 0 0 4.486-6.336l-3.276 3.277a3.004 3.004 0 0 1-2.25-2.25l3.276-3.276a4.5 4.5 0 0 0-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437 1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008Z" />
                    </svg>
                    <span class="mobile-brand-name">{{ __('auth.brand_name') }}</span>
                </div>

                {{-- Form Header --}}
                <div class="form-header">
                    <h2 class="form-heading">{{ $this->getHeading() }}</h2>
                    @if ($subheading = $this->getSubheading())
                        <p class="form-subheading">{{ $subheading }}</p>
                    @endif
                </div>

                {{-- Login Form - Using Filament's content rendering --}}
                <div class="login-form-content">
                    {{ $this->content }}
                </div>

                {{-- Demo Mode Section --}}
                @if($this->isDemoMode())
                    <div class="demo-mode-section">
                        {{-- Divider --}}
                        <div class="demo-divider">
                            <div class="divider-line"></div>
                            <span class="divider-text">{{ __('auth.demo_mode.or_try_demo') }}</span>
                            <div class="divider-line"></div>
                        </div>

                        {{-- Demo Buttons --}}
                        <div class="demo-buttons">
                            @foreach($this->getDemoCredentials() as $credential)
                                <button
                                    type="button"
                                    wire:click="fillDemoCredentials('{{ $credential['email'] }}', '{{ $credential['password'] }}')"
                                    class="demo-button demo-button-{{ $credential['color'] }}"
                                >
                                    <x-filament::icon
                                        :icon="$credential['icon']"
                                        class="demo-button-icon"
                                    />
                                    <span class="demo-button-label">{{ $credential['role'] }}</span>
                                </button>
                            @endforeach
                        </div>

                        {{-- Credentials Info Box --}}
                        <div class="demo-credentials-box">
                            <div class="demo-credentials-header">
                                <x-filament::icon
                                    icon="heroicon-o-information-circle"
                                    class="demo-info-icon"
                                />
                                <h4 class="demo-credentials-title">{{ __('auth.demo_mode.title') }}</h4>
                            </div>
                            <div class="demo-credentials-list">
                                @foreach($this->getDemoCredentials() as $credential)
                                    <div class="demo-credential-item">
                                        <div class="demo-credential-role">
                                            <x-filament::icon
                                                :icon="$credential['icon']"
                                                class="demo-credential-icon demo-credential-icon-{{ $credential['color'] }}"
                                            />
                                            <span class="demo-credential-role-name">{{ $credential['role'] }}</span>
                                        </div>
                                        <div class="demo-credential-details">
                                            <div class="demo-credential-field">
                                                <span class="demo-credential-label">{{ __('auth.demo_mode.email') }}:</span>
                                                <code class="demo-credential-value">{{ $credential['email'] }}</code>
                                            </div>
                                            <div class="demo-credential-field">
                                                <span class="demo-credential-label">{{ __('auth.demo_mode.password') }}:</span>
                                                <code class="demo-credential-value">{{ $credential['password'] }}</code>
                                            </div>
                                        </div>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    </div>
                @endif

                {{-- Footer --}}
                <div class="login-footer">
                    <p>&copy; {{ date('Y') }} {{ __('auth.brand_name') }}. {{ __('auth.all_rights_reserved') }}</p>
                </div>
            </div>
        </div>
    </div>

    {{-- Modals for any actions --}}
    <x-filament-actions::modals />
</div>
