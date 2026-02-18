<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Category;
use App\Models\ServiceProvider;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Database\Seeder;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $this->createAdminUsers();
        $this->createTenantUsers();
        $this->createServiceProviderUsers();
    }

    private function createAdminUsers(): void
    {
        // Create Super Admin
        $superAdmin = User::firstOrCreate(
            ['email' => 'admin@maintenance.local'],
            [
                'name' => 'Super Admin',
                'email' => 'admin@maintenance.local',
                'password' => 'password',
                'phone' => '+966500000001',
                'locale' => 'en',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        $superAdmin->assignRole('super_admin');

        // Create Manager
        $manager = User::firstOrCreate(
            ['email' => 'manager@maintenance.local'],
            [
                'name' => 'Manager',
                'email' => 'manager@maintenance.local',
                'password' => 'password',
                'phone' => '+966500000002',
                'locale' => 'en',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        $manager->assignRole('manager');

        // Create Arabic Manager
        $managerAr = User::firstOrCreate(
            ['email' => 'manager.ar@maintenance.local'],
            [
                'name' => 'مدير النظام',
                'email' => 'manager.ar@maintenance.local',
                'password' => 'password',
                'phone' => '+966500000006',
                'locale' => 'ar',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        $managerAr->assignRole('manager');

        // Create Viewer
        $viewer = User::firstOrCreate(
            ['email' => 'viewer@maintenance.local'],
            [
                'name' => 'Viewer',
                'email' => 'viewer@maintenance.local',
                'password' => 'password',
                'phone' => '+966500000003',
                'locale' => 'en',
                'is_active' => true,
                'email_verified_at' => now(),
            ]
        );
        $viewer->assignRole('viewer');

        // Create Inactive Admin (for testing)
        $inactiveAdmin = User::firstOrCreate(
            ['email' => 'inactive.admin@maintenance.local'],
            [
                'name' => 'Inactive Admin',
                'email' => 'inactive.admin@maintenance.local',
                'password' => 'password',
                'phone' => '+966500000007',
                'locale' => 'en',
                'is_active' => false,
                'email_verified_at' => now(),
            ]
        );
        $inactiveAdmin->assignRole('viewer');

        $this->command->info('Admin users created:');
        $this->command->table(
            ['Name', 'Email', 'Role', 'Locale', 'Active'],
            [
                [$superAdmin->name, $superAdmin->email, 'super_admin', 'en', 'Yes'],
                [$manager->name, $manager->email, 'manager', 'en', 'Yes'],
                [$managerAr->name, $managerAr->email, 'manager', 'ar', 'Yes'],
                [$viewer->name, $viewer->email, 'viewer', 'en', 'Yes'],
                [$inactiveAdmin->name, $inactiveAdmin->email, 'viewer', 'en', 'No'],
            ]
        );
    }

    private function createTenantUsers(): void
    {
        $tenants = [
            ['name' => 'Ahmed Hassan', 'name_ar' => 'أحمد حسن', 'email' => 'tenant1@maintenance.local', 'phone' => '+966501000001', 'unit_number' => 'A-101', 'building_name' => 'Al Noor Tower', 'locale' => 'ar'],
            ['name' => 'Sarah Miller', 'email' => 'tenant2@maintenance.local', 'phone' => '+966501000002', 'unit_number' => 'B-205', 'building_name' => 'Palm Residences', 'locale' => 'en'],
            ['name' => 'Mohammed Ali', 'name_ar' => 'محمد علي', 'email' => 'tenant3@maintenance.local', 'phone' => '+966501000003', 'unit_number' => 'C-310', 'building_name' => 'Al Faisal Complex', 'locale' => 'ar'],
            ['name' => 'Fatima Al-Rashid', 'name_ar' => 'فاطمة الراشد', 'email' => 'tenant4@maintenance.local', 'phone' => '+966501000004', 'unit_number' => 'A-202', 'building_name' => 'Al Noor Tower', 'locale' => 'ar'],
            ['name' => 'John Williams', 'email' => 'tenant5@maintenance.local', 'phone' => '+966501000005', 'unit_number' => 'B-102', 'building_name' => 'Palm Residences', 'locale' => 'en'],
            ['name' => 'Nora Abdullah', 'name_ar' => 'نورة عبدالله', 'email' => 'tenant6@maintenance.local', 'phone' => '+966501000006', 'unit_number' => 'C-405', 'building_name' => 'Al Faisal Complex', 'locale' => 'ar'],
            ['name' => 'David Chen', 'email' => 'tenant7@maintenance.local', 'phone' => '+966501000007', 'unit_number' => 'A-305', 'building_name' => 'Al Noor Tower', 'locale' => 'en'],
            ['name' => 'Layla Mahmoud', 'name_ar' => 'ليلى محمود', 'email' => 'tenant8@maintenance.local', 'phone' => '+966501000008', 'unit_number' => 'B-401', 'building_name' => 'Palm Residences', 'locale' => 'ar'],
            ['name' => 'Hassan Khalid', 'name_ar' => 'حسن خالد', 'email' => 'tenant9@maintenance.local', 'phone' => '+966501000009', 'unit_number' => 'D-101', 'building_name' => 'Desert View', 'locale' => 'ar'],
            ['name' => 'Emily Johnson', 'email' => 'tenant10@maintenance.local', 'phone' => '+966501000010', 'unit_number' => 'A-401', 'building_name' => 'Al Noor Tower', 'locale' => 'en'],
            ['name' => 'Omar Farooq', 'name_ar' => 'عمر فاروق', 'email' => 'tenant11@maintenance.local', 'phone' => '+966501000011', 'unit_number' => 'B-301', 'building_name' => 'Palm Residences', 'locale' => 'ar'],
            ['name' => 'Linda Brown', 'email' => 'tenant12@maintenance.local', 'phone' => '+966501000012', 'unit_number' => 'C-201', 'building_name' => 'Al Faisal Complex', 'locale' => 'en'],
            ['name' => 'Yusuf Ibrahim', 'name_ar' => 'يوسف إبراهيم', 'email' => 'tenant13@maintenance.local', 'phone' => '+966501000013', 'unit_number' => 'D-205', 'building_name' => 'Desert View', 'locale' => 'ar'],
            ['name' => 'Michael Davis', 'email' => 'tenant14@maintenance.local', 'phone' => '+966501000014', 'unit_number' => 'A-501', 'building_name' => 'Al Noor Tower', 'locale' => 'en'],
            ['name' => 'Aisha Ahmed', 'name_ar' => 'عائشة أحمد', 'email' => 'tenant15@maintenance.local', 'phone' => '+966501000015', 'unit_number' => 'B-501', 'building_name' => 'Palm Residences', 'locale' => 'ar'],
            ['name' => 'Robert Garcia', 'email' => 'tenant16@maintenance.local', 'phone' => '+966501000016', 'unit_number' => 'C-105', 'building_name' => 'Al Faisal Complex', 'locale' => 'en'],
            ['name' => 'Mariam Saleh', 'name_ar' => 'مريم صالح', 'email' => 'tenant17@maintenance.local', 'phone' => '+966501000017', 'unit_number' => 'D-301', 'building_name' => 'Desert View', 'locale' => 'ar'],
            ['name' => 'James Wilson', 'email' => 'tenant18@maintenance.local', 'phone' => '+966501000018', 'unit_number' => 'A-601', 'building_name' => 'Al Noor Tower', 'locale' => 'en'],
            ['name' => 'Hanan Mustafa', 'name_ar' => 'حنان مصطفى', 'email' => 'tenant19@maintenance.local', 'phone' => '+966501000019', 'unit_number' => 'B-601', 'building_name' => 'Palm Residences', 'locale' => 'ar'],
            ['name' => 'William Martinez', 'email' => 'tenant20@maintenance.local', 'phone' => '+966501000020', 'unit_number' => 'C-505', 'building_name' => 'Al Faisal Complex', 'locale' => 'en'],
            ['name' => 'Samira Karim', 'name_ar' => 'سميرة كريم', 'email' => 'tenant21@maintenance.local', 'phone' => '+966501000021', 'unit_number' => 'D-401', 'building_name' => 'Desert View', 'locale' => 'ar'],
            ['name' => 'Richard Anderson', 'email' => 'tenant22@maintenance.local', 'phone' => '+966501000022', 'unit_number' => 'A-701', 'building_name' => 'Al Noor Tower', 'locale' => 'en'],
            ['name' => 'Zahra Nasser', 'name_ar' => 'زهراء ناصر', 'email' => 'tenant23@maintenance.local', 'phone' => '+966501000023', 'unit_number' => 'B-701', 'building_name' => 'Palm Residences', 'locale' => 'ar'],
            ['name' => 'Thomas Taylor', 'email' => 'tenant24@maintenance.local', 'phone' => '+966501000024', 'unit_number' => 'C-601', 'building_name' => 'Al Faisal Complex', 'locale' => 'en'],
            ['name' => 'Rania Abdel', 'name_ar' => 'رانيا عبدالله', 'email' => 'tenant25@maintenance.local', 'phone' => '+966501000025', 'unit_number' => 'D-501', 'building_name' => 'Desert View', 'locale' => 'ar'],
            ['name' => 'Charles Jackson', 'email' => 'tenant26@maintenance.local', 'phone' => '+966501000026', 'unit_number' => 'A-801', 'building_name' => 'Al Noor Tower', 'locale' => 'en'],
            ['name' => 'Salma Hassan', 'name_ar' => 'سلمى حسن', 'email' => 'tenant27@maintenance.local', 'phone' => '+966501000027', 'unit_number' => 'B-801', 'building_name' => 'Palm Residences', 'locale' => 'ar'],
            ['name' => 'Daniel White', 'email' => 'tenant28@maintenance.local', 'phone' => '+966501000028', 'unit_number' => 'C-701', 'building_name' => 'Al Faisal Complex', 'locale' => 'en'],
            ['name' => 'Dina Youssef', 'name_ar' => 'دينا يوسف', 'email' => 'tenant29@maintenance.local', 'phone' => '+966501000029', 'unit_number' => 'D-601', 'building_name' => 'Desert View', 'locale' => 'ar'],
            ['name' => 'Matthew Harris', 'email' => 'tenant30@maintenance.local', 'phone' => '+966501000030', 'unit_number' => 'A-901', 'building_name' => 'Al Noor Tower', 'locale' => 'en'],
            // Inactive tenant for testing
            ['name' => 'Inactive Tenant', 'email' => 'inactive.tenant@maintenance.local', 'phone' => '+966501000099', 'unit_number' => 'X-001', 'building_name' => 'Test Building', 'locale' => 'en', 'is_active' => false],
        ];

        $createdTenants = [];

        foreach ($tenants as $tenantData) {
            $isActive = $tenantData['is_active'] ?? true;

            $user = User::firstOrCreate(
                ['email' => $tenantData['email']],
                [
                    'name' => $tenantData['name'],
                    'email' => $tenantData['email'],
                    'password' => 'password',
                    'phone' => $tenantData['phone'],
                    'locale' => $tenantData['locale'],
                    'is_active' => $isActive,
                    'email_verified_at' => now(),
                ]
            );
            $user->assignRole('tenant');

            Tenant::firstOrCreate(
                ['user_id' => $user->id],
                [
                    'user_id' => $user->id,
                    'unit_number' => $tenantData['unit_number'],
                    'building_name' => $tenantData['building_name'],
                ]
            );

            $createdTenants[] = [$user->name, $user->email, $tenantData['unit_number'], $tenantData['building_name'], $isActive ? 'Yes' : 'No'];
        }

        $this->command->info('Tenant users created:');
        $this->command->table(
            ['Name', 'Email', 'Unit', 'Building', 'Active'],
            $createdTenants
        );
    }

    private function createServiceProviderUsers(): void
    {
        // Get categories for assigning to service providers
        $categories = Category::all()->keyBy('name_en');

        $serviceProviders = [
            ['name' => 'Khalid Al-Rashid', 'name_ar' => 'خالد الراشد', 'email' => 'plumber@maintenance.local', 'phone' => '+966502000001', 'categories' => ['Plumbing'], 'locale' => 'ar', 'latitude' => 24.7136, 'longitude' => 46.6753, 'is_available' => true],
            ['name' => 'John Smith', 'email' => 'electrician@maintenance.local', 'phone' => '+966502000002', 'categories' => ['Electrical'], 'locale' => 'en', 'latitude' => 24.7200, 'longitude' => 46.6800, 'is_available' => true],
            ['name' => 'Omar Farooq', 'name_ar' => 'عمر فاروق', 'email' => 'hvac@maintenance.local', 'phone' => '+966502000003', 'categories' => ['HVAC'], 'locale' => 'ar', 'latitude' => 24.7100, 'longitude' => 46.6700, 'is_available' => true],
            ['name' => 'Ali Hassan', 'name_ar' => 'علي حسن', 'email' => 'cleaner@maintenance.local', 'phone' => '+966502000004', 'categories' => ['Cleaning'], 'locale' => 'ar', 'latitude' => 24.7150, 'longitude' => 46.6750, 'is_available' => true],
            ['name' => 'Abdullah Saeed', 'name_ar' => 'عبدالله سعيد', 'email' => 'carpenter@maintenance.local', 'phone' => '+966502000005', 'categories' => ['Carpentry', 'Painting'], 'locale' => 'ar', 'latitude' => 24.7180, 'longitude' => 46.6780, 'is_available' => true],
            ['name' => 'Mike Johnson', 'email' => 'general@maintenance.local', 'phone' => '+966502000006', 'categories' => ['General Maintenance', 'Carpentry'], 'locale' => 'en', 'latitude' => 24.7220, 'longitude' => 46.6820, 'is_available' => true],
            ['name' => 'Yusuf Ibrahim', 'name_ar' => 'يوسف إبراهيم', 'email' => 'multi.skilled@maintenance.local', 'phone' => '+966502000007', 'categories' => ['Plumbing', 'Electrical', 'General Maintenance'], 'locale' => 'ar', 'latitude' => 24.7160, 'longitude' => 46.6760, 'is_available' => true],
            ['name' => 'Sam Wilson', 'email' => 'pest.control@maintenance.local', 'phone' => '+966502000008', 'categories' => ['Pest Control', 'Cleaning'], 'locale' => 'en', 'latitude' => 24.7140, 'longitude' => 46.6740, 'is_available' => true],
            ['name' => 'Rashid Ahmed', 'name_ar' => 'راشد أحمد', 'email' => 'landscape@maintenance.local', 'phone' => '+966502000009', 'categories' => ['Landscaping', 'Cleaning'], 'locale' => 'ar', 'latitude' => 24.7190, 'longitude' => 46.6790, 'is_available' => true],
            ['name' => 'Security Guard', 'email' => 'security@maintenance.local', 'phone' => '+966502000010', 'categories' => ['Security'], 'locale' => 'en', 'latitude' => 24.7170, 'longitude' => 46.6770, 'is_available' => true],
            ['name' => 'Ibrahim Malik', 'name_ar' => 'إبراهيم مالك', 'email' => 'plumber2@maintenance.local', 'phone' => '+966502000011', 'categories' => ['Plumbing'], 'locale' => 'ar', 'latitude' => 24.7145, 'longitude' => 46.6755, 'is_available' => true],
            ['name' => 'Peter Brown', 'email' => 'electrician2@maintenance.local', 'phone' => '+966502000012', 'categories' => ['Electrical'], 'locale' => 'en', 'latitude' => 24.7205, 'longitude' => 46.6805, 'is_available' => true],
            ['name' => 'Samir Zaki', 'name_ar' => 'سمير زكي', 'email' => 'hvac2@maintenance.local', 'phone' => '+966502000013', 'categories' => ['HVAC'], 'locale' => 'ar', 'latitude' => 24.7105, 'longitude' => 46.6705, 'is_available' => true],
            ['name' => 'Mark Davis', 'email' => 'painter@maintenance.local', 'phone' => '+966502000014', 'categories' => ['Painting'], 'locale' => 'en', 'latitude' => 24.7165, 'longitude' => 46.6765, 'is_available' => true],
            ['name' => 'Tariq Hussain', 'name_ar' => 'طارق حسين', 'email' => 'cleaner2@maintenance.local', 'phone' => '+966502000015', 'categories' => ['Cleaning'], 'locale' => 'ar', 'latitude' => 24.7155, 'longitude' => 46.6755, 'is_available' => true],
            ['name' => 'Steve Martin', 'email' => 'carpenter2@maintenance.local', 'phone' => '+966502000016', 'categories' => ['Carpentry'], 'locale' => 'en', 'latitude' => 24.7185, 'longitude' => 46.6785, 'is_available' => true],
            ['name' => 'Nabil Amin', 'name_ar' => 'نبيل أمين', 'email' => 'pool.maintenance@maintenance.local', 'phone' => '+966502000017', 'categories' => ['Swimming Pool'], 'locale' => 'ar', 'latitude' => 24.7175, 'longitude' => 46.6775, 'is_available' => true],
            ['name' => 'Paul Garcia', 'email' => 'elevator@maintenance.local', 'phone' => '+966502000018', 'categories' => ['Elevator Maintenance'], 'locale' => 'en', 'latitude' => 24.7195, 'longitude' => 46.6795, 'is_available' => true],
            ['name' => 'Faisal Rahman', 'name_ar' => 'فيصل الرحمن', 'email' => 'flooring@maintenance.local', 'phone' => '+966502000019', 'categories' => ['Flooring'], 'locale' => 'ar', 'latitude' => 24.7125, 'longitude' => 46.6725, 'is_available' => true],
            ['name' => 'Brian Moore', 'email' => 'roofing@maintenance.local', 'phone' => '+966502000020', 'categories' => ['Roofing'], 'locale' => 'en', 'latitude' => 24.7135, 'longitude' => 46.6735, 'is_available' => true],
            ['name' => 'Waleed Sherif', 'name_ar' => 'وليد شريف', 'email' => 'appliance@maintenance.local', 'phone' => '+966502000021', 'categories' => ['Appliance Repair'], 'locale' => 'ar', 'latitude' => 24.7215, 'longitude' => 46.6815, 'is_available' => true],
            ['name' => 'Kevin Taylor', 'email' => 'multi.skilled2@maintenance.local', 'phone' => '+966502000022', 'categories' => ['Plumbing', 'Electrical'], 'locale' => 'en', 'latitude' => 24.7165, 'longitude' => 46.6765, 'is_available' => true],
            ['name' => 'Mahmoud Farid', 'name_ar' => 'محمود فريد', 'email' => 'multi.skilled3@maintenance.local', 'phone' => '+966502000023', 'categories' => ['HVAC', 'Electrical'], 'locale' => 'ar', 'latitude' => 24.7115, 'longitude' => 46.6715, 'is_available' => true],
            ['name' => 'Andrew Wilson', 'email' => 'multi.skilled4@maintenance.local', 'phone' => '+966502000024', 'categories' => ['Carpentry', 'Flooring'], 'locale' => 'en', 'latitude' => 24.7190, 'longitude' => 46.6790, 'is_available' => true],
            ['name' => 'Adel Moustafa', 'name_ar' => 'عادل مصطفى', 'email' => 'multi.skilled5@maintenance.local', 'phone' => '+966502000025', 'categories' => ['Painting', 'Carpentry'], 'locale' => 'ar', 'latitude' => 24.7170, 'longitude' => 46.6770, 'is_available' => true],
            ['name' => 'Christopher Lee', 'email' => 'general2@maintenance.local', 'phone' => '+966502000026', 'categories' => ['General Maintenance'], 'locale' => 'en', 'latitude' => 24.7225, 'longitude' => 46.6825, 'is_available' => true],
            ['name' => 'Hamza Yasser', 'name_ar' => 'حمزة ياسر', 'email' => 'pest.control2@maintenance.local', 'phone' => '+966502000027', 'categories' => ['Pest Control'], 'locale' => 'ar', 'latitude' => 24.7145, 'longitude' => 46.6745, 'is_available' => true],
            ['name' => 'Jason White', 'email' => 'landscape2@maintenance.local', 'phone' => '+966502000028', 'categories' => ['Landscaping'], 'locale' => 'en', 'latitude' => 24.7195, 'longitude' => 46.6795, 'is_available' => true],
            ['name' => 'Karim Naguib', 'name_ar' => 'كريم نجيب', 'email' => 'security2@maintenance.local', 'phone' => '+966502000029', 'categories' => ['Security'], 'locale' => 'ar', 'latitude' => 24.7175, 'longitude' => 46.6775, 'is_available' => true],
            ['name' => 'Ryan Harris', 'email' => 'plumber3@maintenance.local', 'phone' => '+966502000030', 'categories' => ['Plumbing'], 'locale' => 'en', 'latitude' => 24.7140, 'longitude' => 46.6740, 'is_available' => true],
            // Unavailable service provider for testing
            ['name' => 'Unavailable Worker', 'email' => 'unavailable@maintenance.local', 'phone' => '+966502000098', 'categories' => ['Plumbing'], 'locale' => 'en', 'latitude' => 24.7130, 'longitude' => 46.6730, 'is_available' => false],
            // Inactive service provider for testing
            ['name' => 'Inactive Worker', 'email' => 'inactive.sp@maintenance.local', 'phone' => '+966502000099', 'categories' => ['Electrical'], 'locale' => 'en', 'latitude' => 24.7125, 'longitude' => 46.6725, 'is_available' => true, 'is_active' => false],
        ];

        $createdProviders = [];

        foreach ($serviceProviders as $providerData) {
            $categoryIds = [];
            foreach ($providerData['categories'] as $categoryName) {
                $category = $categories->get($categoryName);
                if ($category) {
                    $categoryIds[] = $category->id;
                }
            }

            if (empty($categoryIds)) {
                $this->command->warn("Skipping {$providerData['name']} - no categories found. Run CategorySeeder first.");

                continue;
            }

            $isActive = $providerData['is_active'] ?? true;

            $user = User::firstOrCreate(
                ['email' => $providerData['email']],
                [
                    'name' => $providerData['name'],
                    'email' => $providerData['email'],
                    'password' => 'password',
                    'phone' => $providerData['phone'],
                    'locale' => $providerData['locale'],
                    'is_active' => $isActive,
                    'email_verified_at' => now(),
                ]
            );
            $user->assignRole('service_provider');

            $serviceProvider = ServiceProvider::firstOrCreate(
                ['user_id' => $user->id],
                [
                    'user_id' => $user->id,
                    'latitude' => $providerData['latitude'],
                    'longitude' => $providerData['longitude'],
                    'is_available' => $providerData['is_available'],
                ]
            );

            // Attach categories (many-to-many)
            $serviceProvider->categories()->syncWithoutDetaching($categoryIds);

            $createdProviders[] = [
                $user->name,
                $user->email,
                implode(', ', $providerData['categories']),
                $providerData['is_available'] ? 'Yes' : 'No',
                $isActive ? 'Yes' : 'No',
            ];
        }

        $this->command->info('Service Provider users created:');
        $this->command->table(
            ['Name', 'Email', 'Categories', 'Available', 'Active'],
            $createdProviders
        );

        $this->command->newLine();
        $this->command->warn('Default password for all users: password');
    }
}
