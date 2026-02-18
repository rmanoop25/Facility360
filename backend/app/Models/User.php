<?php

declare(strict_types=1);

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Spatie\Permission\Traits\HasRoles;
use PHPOpenSourceSaver\JWTAuth\Contracts\JWTSubject;

class User extends Authenticatable implements JWTSubject, FilamentUser
{
    use HasFactory, Notifiable, HasRoles;

    /**
     * Guard name for Spatie Permission.
     * Ensures permissions work correctly via both web and API (JWT) authentication.
     */
    protected string $guard_name = 'web';

    protected $fillable = [
        'name',
        'profile_photo',
        'email',
        'password',
        'phone',
        'fcm_token',
        'locale',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    // JWT methods
    public function getJWTIdentifier(): mixed
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims(): array
    {
        return [];
    }

    // Relationships
    public function tenant(): HasOne
    {
        return $this->hasOne(Tenant::class);
    }

    public function serviceProvider(): HasOne
    {
        return $this->hasOne(ServiceProvider::class);
    }

    // Helpers
    public function isTenant(): bool
    {
        return $this->tenant()->exists();
    }

    public function isServiceProvider(): bool
    {
        return $this->serviceProvider()->exists();
    }

    public function isAdmin(): bool
    {
        // Any role except tenant/service_provider is considered admin
        return !$this->hasRole(['tenant', 'service_provider']) && $this->roles()->exists();
    }

    public function canAccessPanel(Panel $panel): bool
    {
        // Block mobile-only roles (tenant, service_provider)
        // All other roles can access the admin panel
        if ($this->hasRole(['tenant', 'service_provider'])) {
            return false;
        }

        // Must have at least one role and be active
        return $this->roles()->exists() && $this->is_active;
    }

    public function getLocalizedName(string $locale = null): string
    {
        return $this->name;
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope to get all admin users (any role except tenant/service_provider).
     * This is dynamic - works with any custom admin roles.
     */
    public function scopeAdmins($query)
    {
        return $query->whereHas('roles', fn ($q) => $q->whereNotIn('name', ['tenant', 'service_provider']));
    }
}
