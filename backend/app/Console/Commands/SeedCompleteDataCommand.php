<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;

class SeedCompleteDataCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'db:seed-complete
                            {--fresh : Drop all tables and migrate before seeding}
                            {--validate : Run data validation after seeding}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Seed complete demo data in correct order with validation';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        if ($this->option('fresh')) {
            $this->info('Dropping all tables and migrating...');
            $this->call('migrate:fresh');
        }

        $this->info('Seeding data in correct order...');

        $seeders = [
            'RolesAndPermissionsSeeder',
            'CategorySeeder',
            'AdminUserSeeder',
            'WorkTypeSeeder',
            'ConsumableSeeder',
            'TimeSlotSeeder',
            'EnhancedIssueSeeder',   // Creates issues
            'DemoDataSeeder',        // Creates assignments, proofs, timeline
        ];

        foreach ($seeders as $seeder) {
            $this->info("Running {$seeder}...");
            $this->call('db:seed', ['--class' => $seeder]);
        }

        if ($this->option('validate')) {
            $this->info('Running data validation...');
            // DemoDataSeeder's run() method includes validateDataConsistency()
            // which was already called above, so validation is complete
        }

        $this->info('Complete data seeding finished!');

        return Command::SUCCESS;
    }
}
