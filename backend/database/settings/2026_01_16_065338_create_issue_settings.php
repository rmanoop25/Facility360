<?php

use Spatie\LaravelSettings\Migrations\SettingsMigration;

return new class extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('issue.auto_approve_finished_issues', false);
    }

    public function down(): void
    {
        $this->migrator->delete('issue.auto_approve_finished_issues');
    }
};
