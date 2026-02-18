<?php

declare(strict_types=1);

namespace App\Enums;

enum UserRole: string
{
    case SUPER_ADMIN = 'super_admin';
    case MANAGER = 'manager';
    case VIEWER = 'viewer';
    case TENANT = 'tenant';
    case SERVICE_PROVIDER = 'service_provider';

    public function label(): string
    {
        return match ($this) {
            self::SUPER_ADMIN => __('users.roles.super_admin'),
            self::MANAGER => __('users.roles.manager'),
            self::VIEWER => __('users.roles.viewer'),
            self::TENANT => __('users.roles.tenant'),
            self::SERVICE_PROVIDER => __('users.roles.service_provider'),
        };
    }

    public function isAdmin(): bool
    {
        return in_array($this, [self::SUPER_ADMIN, self::MANAGER, self::VIEWER]);
    }

    public function isMobile(): bool
    {
        return in_array($this, [self::TENANT, self::SERVICE_PROVIDER]);
    }

    public static function adminRoles(): array
    {
        return [self::SUPER_ADMIN, self::MANAGER, self::VIEWER];
    }

    public static function mobileRoles(): array
    {
        return [self::TENANT, self::SERVICE_PROVIDER];
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public static function options(): array
    {
        return collect(self::cases())
            ->mapWithKeys(fn (self $role) => [$role->value => $role->label()])
            ->toArray();
    }
}
