<?php

declare(strict_types=1);

namespace App\Filament\Pages\Auth;

use Filament\Auth\Pages\Login as FilamentLogin;
use Filament\Support\Enums\Width;
use Illuminate\Contracts\Support\Htmlable;

class Login extends FilamentLogin
{
    protected string $view = 'filament.pages.auth.login';

    public function getTitle(): string|Htmlable
    {
        return __('auth.login_title');
    }

    public function getHeading(): string|Htmlable
    {
        return __('auth.welcome_back');
    }

    public function getSubheading(): string|Htmlable|null
    {
        return __('auth.login_subtitle');
    }

    public function hasLogo(): bool
    {
        return false;
    }

    public function getMaxContentWidth(): Width|string|null
    {
        return Width::Full;
    }

    public function getMaxWidth(): Width|string|null
    {
        return Width::Full;
    }

    public function isDemoMode(): bool
    {
        return (bool) config('app.demo_mode', false);
    }

    /**
     * @return array<int, array{role: string, icon: string, color: string, email: string, password: string}>
     */
    public function getDemoCredentials(): array
    {
        return [
            [
                'role' => __('auth.demo_mode.roles.super_admin'),
                'icon' => 'heroicon-o-shield-check',
                'color' => 'primary',
                'email' => 'admin@maintenance.local',
                'password' => 'password',
            ],
            [
                'role' => __('auth.demo_mode.roles.manager'),
                'icon' => 'heroicon-o-briefcase',
                'color' => 'success',
                'email' => 'manager@maintenance.local',
                'password' => 'password',
            ],
            [
                'role' => __('auth.demo_mode.roles.viewer'),
                'icon' => 'heroicon-o-eye',
                'color' => 'warning',
                'email' => 'viewer@maintenance.local',
                'password' => 'password',
            ],
        ];
    }

    public function fillDemoCredentials(string $email, string $password): void
    {
        $this->form->fill([
            'email' => $email,
            'password' => $password,
        ]);
    }
}
