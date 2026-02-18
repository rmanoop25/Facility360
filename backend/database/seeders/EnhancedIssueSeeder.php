<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Enums\IssuePriority;
use App\Enums\IssueStatus;
use App\Enums\MediaType;
use App\Models\Category;
use App\Models\Issue;
use App\Models\IssueMedia;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Database\Seeder;

class EnhancedIssueSeeder extends Seeder
{
    public function run(): void
    {
        $tenants = Tenant::with('user')->get();

        if ($tenants->isEmpty()) {
            $this->command->warn('No tenants found. Run AdminUserSeeder first.');

            return;
        }

        $categories = Category::all();

        if ($categories->isEmpty()) {
            $this->command->warn('No categories found. Run CategorySeeder first.');

            return;
        }

        $issues = $this->getIssueData();
        $createdIssues = [];

        foreach ($issues as $index => $issueData) {
            // Get tenant by index (cycle through tenants)
            $tenant = $tenants[$index % $tenants->count()];

            // Get categories for this issue
            $issueCategoryNames = $issueData['categories'];
            $issueCategories = $categories->filter(
                fn ($cat) => in_array($cat->name_en, $issueCategoryNames)
            );

            if ($issueCategories->isEmpty()) {
                continue;
            }

            // Create the issue
            $issue = Issue::firstOrCreate(
                [
                    'tenant_id' => $tenant->id,
                    'title' => $issueData['title'],
                ],
                [
                    'tenant_id' => $tenant->id,
                    'title' => $issueData['title'],
                    'description' => $issueData['description'],
                    'status' => $issueData['status'],
                    'priority' => $issueData['priority'],
                    'latitude' => $issueData['latitude'],
                    'longitude' => $issueData['longitude'],
                    'proof_required' => $issueData['proof_required'],
                    'cancelled_reason' => $issueData['cancelled_reason'],
                    'cancelled_by' => $issueData['cancelled_by'],
                    'cancelled_at' => $issueData['cancelled_at'],
                    'created_at' => $issueData['created_at'],
                    'updated_at' => $issueData['updated_at'],
                ]
            );

            // Attach categories
            $issue->categories()->syncWithoutDetaching($issueCategories->pluck('id'));

            // Attach media files if specified
            if (isset($issueData['media']) && is_array($issueData['media'])) {
                foreach ($issueData['media'] as $mediaData) {
                    IssueMedia::firstOrCreate(
                        [
                            'issue_id' => $issue->id,
                            'file_path' => $mediaData['path'],
                        ],
                        [
                            'type' => $mediaData['type'],
                        ]
                    );
                }
            }

            $createdIssues[] = [
                $issue->id,
                substr($issue->title, 0, 40).'...',
                $tenant->unit_number,
                $issueData['status']->value,
                $issueData['priority']->value,
            ];
        }

        $this->command->info('Issues created: '.count($createdIssues));
        $this->command->table(
            ['ID', 'Title', 'Unit', 'Status', 'Priority'],
            array_slice($createdIssues, 0, 20) // Show first 20 only
        );

        $this->displayStatusSummary();
    }

    private function getIssueData(): array
    {
        $now = now();
        $adminUser = User::where('email', 'admin@maintenance.local')->first();
        $adminId = $adminUser?->id;

        return [
            // PENDING issues (8 issues)
            ['title' => 'Water leak under kitchen sink', 'description' => 'There is a persistent water leak under my kitchen sink. The pipe connection seems loose and water is pooling on the cabinet floor. Need urgent repair.', 'status' => IssueStatus::PENDING, 'priority' => IssuePriority::HIGH, 'categories' => ['Plumbing'], 'latitude' => 24.7140, 'longitude' => 46.6755, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(1)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(1)->format('Y-m-d H:i:s'), 'media' => [['type' => MediaType::PHOTO, 'path' => 'issues/Work_7.jpg'], ['type' => MediaType::PHOTO, 'path' => 'issues/40796.jpg']]],
            ['title' => 'Bedroom light not working', 'description' => 'The main ceiling light in the master bedroom stopped working. I have tried replacing the bulb but it still does not turn on. Might be a wiring issue.', 'status' => IssueStatus::PENDING, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Electrical'], 'latitude' => 24.7205, 'longitude' => 46.6810, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s')],
            ['title' => 'AC making loud noise', 'description' => 'The air conditioning unit in the living room is making a loud rattling noise when running. It is very disturbing especially at night.', 'status' => IssueStatus::PENDING, 'priority' => IssuePriority::LOW, 'categories' => ['HVAC'], 'latitude' => 24.7110, 'longitude' => 46.6710, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subHours(12)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(12)->format('Y-m-d H:i:s'), 'media' => [['type' => MediaType::VIDEO, 'path' => 'issues/1112999_Brainstorm_Typing_3840x2160.mp4']]],
            ['title' => 'Broken door handle', 'description' => 'The handle on the main entrance door is broken and does not close properly. This is a security concern.', 'status' => IssueStatus::PENDING, 'priority' => IssuePriority::HIGH, 'categories' => ['Carpentry', 'General Maintenance'], 'latitude' => 24.7185, 'longitude' => 46.6785, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subHours(6)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(6)->format('Y-m-d H:i:s')],
            ['title' => 'Cracked bathroom tiles', 'description' => 'Several tiles in the bathroom floor are cracked and need to be replaced. Water might seep underneath.', 'status' => IssueStatus::PENDING, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Flooring'], 'latitude' => 24.7150, 'longitude' => 46.6750, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(1)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(1)->format('Y-m-d H:i:s')],
            ['title' => 'Cockroaches in kitchen', 'description' => 'I have been seeing cockroaches in my kitchen for the past week. Need pest control service urgently.', 'status' => IssueStatus::PENDING, 'priority' => IssuePriority::HIGH, 'categories' => ['Pest Control'], 'latitude' => 24.7160, 'longitude' => 46.6760, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subHours(18)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(18)->format('Y-m-d H:i:s'), 'media' => [['type' => MediaType::PHOTO, 'path' => 'issues/3785602.jpg']]],
            ['title' => 'Washing machine not draining', 'description' => 'The washing machine is not draining water properly. Water stays in the drum after the cycle.', 'status' => IssueStatus::PENDING, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Appliance Repair'], 'latitude' => 24.7170, 'longitude' => 46.6770, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subHours(8)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(8)->format('Y-m-d H:i:s')],
            ['title' => 'Garden needs trimming', 'description' => 'The garden plants have grown too much and need professional trimming and maintenance.', 'status' => IssueStatus::PENDING, 'priority' => IssuePriority::LOW, 'categories' => ['Landscaping'], 'latitude' => 24.7190, 'longitude' => 46.6790, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subHours(4)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(4)->format('Y-m-d H:i:s')],

            // ASSIGNED issues (6 issues)
            ['title' => 'Clogged bathroom drain', 'description' => 'The drain in the bathroom sink is completely clogged. Water takes a very long time to drain.', 'status' => IssueStatus::ASSIGNED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Plumbing'], 'latitude' => 24.7145, 'longitude' => 46.6760, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(3)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(1)->format('Y-m-d H:i:s')],
            ['title' => 'Wall socket sparking', 'description' => 'One of the wall sockets in the living room is sparking when I plug in appliances. This is dangerous.', 'status' => IssueStatus::ASSIGNED, 'priority' => IssuePriority::HIGH, 'categories' => ['Electrical'], 'latitude' => 24.7210, 'longitude' => 46.6815, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(18)->format('Y-m-d H:i:s')],
            ['title' => 'Window screen torn', 'description' => 'The window screen in the bedroom is torn and insects are coming in. Need replacement.', 'status' => IssueStatus::ASSIGNED, 'priority' => IssuePriority::LOW, 'categories' => ['Carpentry'], 'latitude' => 24.7175, 'longitude' => 46.6775, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(3)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s')],
            ['title' => 'Roof leak during rain', 'description' => 'Water is leaking from the ceiling in the bedroom when it rains. The roof needs inspection and repair.', 'status' => IssueStatus::ASSIGNED, 'priority' => IssuePriority::HIGH, 'categories' => ['Roofing'], 'latitude' => 24.7135, 'longitude' => 46.6735, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(4)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s')],
            ['title' => 'Elevator making noise', 'description' => 'The building elevator is making strange grinding noises. Should be checked for safety.', 'status' => IssueStatus::ASSIGNED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Elevator Maintenance'], 'latitude' => 24.7195, 'longitude' => 46.6795, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(1)->format('Y-m-d H:i:s')],
            ['title' => 'Pool pump not working', 'description' => 'The swimming pool pump has stopped working. Water is becoming dirty.', 'status' => IssueStatus::ASSIGNED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Swimming Pool'], 'latitude' => 24.7165, 'longitude' => 46.6765, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(3)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(20)->format('Y-m-d H:i:s')],

            // IN_PROGRESS issues (7 issues)
            ['title' => 'AC not cooling properly', 'description' => 'The air conditioner is running but not cooling the room effectively. Temperature stays high even after hours of running.', 'status' => IssueStatus::IN_PROGRESS, 'priority' => IssuePriority::HIGH, 'categories' => ['HVAC'], 'latitude' => 24.7115, 'longitude' => 46.6715, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(4)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(2)->format('Y-m-d H:i:s')],
            ['title' => 'Kitchen cabinet door falling off', 'description' => 'One of the kitchen cabinet doors has loose hinges and is about to fall off. Need repair urgently.', 'status' => IssueStatus::IN_PROGRESS, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Carpentry'], 'latitude' => 24.7190, 'longitude' => 46.6790, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(5)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(4)->format('Y-m-d H:i:s')],
            ['title' => 'Balcony deep cleaning needed', 'description' => 'The balcony has not been deep cleaned in a while. There is accumulated dust and dirt that needs professional cleaning.', 'status' => IssueStatus::IN_PROGRESS, 'priority' => IssuePriority::LOW, 'categories' => ['Cleaning'], 'latitude' => 24.7155, 'longitude' => 46.6755, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(3)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(1)->format('Y-m-d H:i:s'), 'media' => [['type' => MediaType::PHOTO, 'path' => 'issues/Work_from_home.jpg']]],
            ['title' => 'Front door needs repainting', 'description' => 'The paint on the front door is peeling badly. It needs sanding and repainting.', 'status' => IssueStatus::IN_PROGRESS, 'priority' => IssuePriority::LOW, 'categories' => ['Painting'], 'latitude' => 24.7180, 'longitude' => 46.6780, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(6)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(3)->format('Y-m-d H:i:s')],
            ['title' => 'Refrigerator not cooling', 'description' => 'The refrigerator is not maintaining proper temperature. Food is spoiling.', 'status' => IssueStatus::IN_PROGRESS, 'priority' => IssuePriority::HIGH, 'categories' => ['Appliance Repair'], 'latitude' => 24.7215, 'longitude' => 46.6815, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(5)->format('Y-m-d H:i:s')],
            ['title' => 'Security camera offline', 'description' => 'One of the security cameras in the parking area is offline. Need to check connection and fix.', 'status' => IssueStatus::IN_PROGRESS, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Security'], 'latitude' => 24.7170, 'longitude' => 46.6770, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(3)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(2)->format('Y-m-d H:i:s')],
            ['title' => 'Laminate flooring lifting', 'description' => 'Some sections of the laminate flooring in the hallway are lifting up. Need to be reglued or replaced.', 'status' => IssueStatus::IN_PROGRESS, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Flooring'], 'latitude' => 24.7125, 'longitude' => 46.6725, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(4)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(6)->format('Y-m-d H:i:s')],

            // ON_HOLD issues (3 issues)
            ['title' => 'Toilet flush mechanism broken', 'description' => 'The toilet flush is not working. The mechanism inside the tank seems to be broken.', 'status' => IssueStatus::ON_HOLD, 'priority' => IssuePriority::HIGH, 'categories' => ['Plumbing'], 'latitude' => 24.7150, 'longitude' => 46.6765, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(6)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(8)->format('Y-m-d H:i:s')],
            ['title' => 'Living room wall needs repainting', 'description' => 'The paint on the living room wall is peeling and looks unsightly. Needs repainting.', 'status' => IssueStatus::ON_HOLD, 'priority' => IssuePriority::LOW, 'categories' => ['Painting'], 'latitude' => 24.7195, 'longitude' => 46.6795, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(7)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s')],
            ['title' => 'Oven heating element faulty', 'description' => 'The oven is not heating up properly. The heating element appears to be damaged.', 'status' => IssueStatus::ON_HOLD, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Appliance Repair'], 'latitude' => 24.7200, 'longitude' => 46.6800, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(5)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(1)->format('Y-m-d H:i:s')],

            // FINISHED issues (4 issues)
            ['title' => 'Water heater not working', 'description' => 'The water heater has stopped working completely. No hot water available.', 'status' => IssueStatus::FINISHED, 'priority' => IssuePriority::HIGH, 'categories' => ['Plumbing', 'Electrical'], 'latitude' => 24.7160, 'longitude' => 46.6770, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(8)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(3)->format('Y-m-d H:i:s')],
            ['title' => 'Fan blade wobbling', 'description' => 'The ceiling fan in the bedroom wobbles when running at high speed. Need to fix the balance.', 'status' => IssueStatus::FINISHED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Electrical', 'General Maintenance'], 'latitude' => 24.7200, 'longitude' => 46.6800, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(5)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(6)->format('Y-m-d H:i:s')],
            ['title' => 'Termite treatment needed', 'description' => 'Found signs of termites in the wooden furniture. Need professional treatment.', 'status' => IssueStatus::FINISHED, 'priority' => IssuePriority::HIGH, 'categories' => ['Pest Control'], 'latitude' => 24.7140, 'longitude' => 46.6740, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(10)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(2)->format('Y-m-d H:i:s')],
            ['title' => 'Install new door lock', 'description' => 'Need to install a new smart lock on the main entrance door.', 'status' => IssueStatus::FINISHED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Security', 'Carpentry'], 'latitude' => 24.7175, 'longitude' => 46.6785, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(6)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subHours(12)->format('Y-m-d H:i:s')],

            // COMPLETED issues (8 issues)
            ['title' => 'Leaky faucet in bathroom', 'description' => 'The bathroom faucet has been dripping constantly. Washer needs replacement.', 'status' => IssueStatus::COMPLETED, 'priority' => IssuePriority::LOW, 'categories' => ['Plumbing'], 'latitude' => 24.7165, 'longitude' => 46.6775, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(15)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(10)->format('Y-m-d H:i:s')],
            ['title' => 'Light switch replacement', 'description' => 'The light switch in the kitchen needs to be replaced as it is broken.', 'status' => IssueStatus::COMPLETED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Electrical'], 'latitude' => 24.7170, 'longitude' => 46.6780, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(20)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(15)->format('Y-m-d H:i:s')],
            ['title' => 'AC filter cleaning', 'description' => 'Regular maintenance - AC filters need to be cleaned.', 'status' => IssueStatus::COMPLETED, 'priority' => IssuePriority::LOW, 'categories' => ['HVAC', 'Cleaning'], 'latitude' => 24.7120, 'longitude' => 46.6720, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(30)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(25)->format('Y-m-d H:i:s')],
            ['title' => 'Door lock replacement', 'description' => 'The door lock on the bedroom door needs to be replaced.', 'status' => IssueStatus::COMPLETED, 'priority' => IssuePriority::HIGH, 'categories' => ['Carpentry', 'Security'], 'latitude' => 24.7175, 'longitude' => 46.6785, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(25)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(20)->format('Y-m-d H:i:s')],
            ['title' => 'Pest control treatment', 'description' => 'Quarterly pest control treatment needed for the apartment.', 'status' => IssueStatus::COMPLETED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Pest Control'], 'latitude' => 24.7145, 'longitude' => 46.6745, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(45)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(40)->format('Y-m-d H:i:s')],
            ['title' => 'Garden maintenance', 'description' => 'Monthly garden and landscaping maintenance for the common area.', 'status' => IssueStatus::COMPLETED, 'priority' => IssuePriority::LOW, 'categories' => ['Landscaping'], 'latitude' => 24.7195, 'longitude' => 46.6795, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(35)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(30)->format('Y-m-d H:i:s')],
            ['title' => 'Apartment deep cleaning', 'description' => 'Complete deep cleaning service for the entire apartment before moving in.', 'status' => IssueStatus::COMPLETED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Cleaning'], 'latitude' => 24.7185, 'longitude' => 46.6785, 'proof_required' => false, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(50)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(48)->format('Y-m-d H:i:s')],
            ['title' => 'Install new ceiling fan', 'description' => 'Installed a new ceiling fan in the living room for better air circulation.', 'status' => IssueStatus::COMPLETED, 'priority' => IssuePriority::LOW, 'categories' => ['Electrical', 'General Maintenance'], 'latitude' => 24.7130, 'longitude' => 46.6730, 'proof_required' => true, 'cancelled_reason' => null, 'cancelled_by' => null, 'cancelled_at' => null, 'created_at' => $now->copy()->subDays(40)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(35)->format('Y-m-d H:i:s')],

            // CANCELLED issues (2 issues)
            ['title' => 'Window cleaning request', 'description' => 'External window cleaning requested. Later decided to do it myself.', 'status' => IssueStatus::CANCELLED, 'priority' => IssuePriority::LOW, 'categories' => ['Cleaning'], 'latitude' => 24.7180, 'longitude' => 46.6780, 'proof_required' => false, 'cancelled_reason' => 'Tenant decided to clean windows themselves', 'cancelled_by' => $adminId, 'cancelled_at' => $now->copy()->subDays(5)->format('Y-m-d H:i:s'), 'created_at' => $now->copy()->subDays(10)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(5)->format('Y-m-d H:i:s')],
            ['title' => 'Duplicate plumbing request', 'description' => 'This was a duplicate request for the same issue.', 'status' => IssueStatus::CANCELLED, 'priority' => IssuePriority::MEDIUM, 'categories' => ['Plumbing'], 'latitude' => 24.7155, 'longitude' => 46.6760, 'proof_required' => true, 'cancelled_reason' => 'Duplicate request - already addressed in another ticket', 'cancelled_by' => $adminId, 'cancelled_at' => $now->copy()->subDays(12)->format('Y-m-d H:i:s'), 'created_at' => $now->copy()->subDays(14)->format('Y-m-d H:i:s'), 'updated_at' => $now->copy()->subDays(12)->format('Y-m-d H:i:s')],
        ];
    }

    private function displayStatusSummary(): void
    {
        $summary = Issue::selectRaw('status, COUNT(*) as count')
            ->groupBy('status')
            ->pluck('count', 'status')
            ->toArray();

        $statusData = [];
        foreach (IssueStatus::cases() as $status) {
            $statusData[] = [
                $status->value,
                $summary[$status->value] ?? 0,
            ];
        }

        $this->command->newLine();
        $this->command->info('Issue status summary:');
        $this->command->table(['Status', 'Count'], $statusData);
    }
}
