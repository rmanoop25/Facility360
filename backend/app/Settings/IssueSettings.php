<?php

declare(strict_types=1);

namespace App\Settings;

use Spatie\LaravelSettings\Settings;

class IssueSettings extends Settings
{
    public bool $auto_approve_finished_issues;

    public static function group(): string
    {
        return 'issue';
    }
}
