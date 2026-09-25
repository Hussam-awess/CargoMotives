<?php

namespace Tests\Feature\Console;

use App\Models\Notification;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NotifyFeaturedExpiringSoonTest extends TestCase
{
    use RefreshDatabase;

    public function test_warns_a_customer_whose_plus_expires_inside_the_window(): void
    {
        config(['featured.expiry_reminder_days_before' => 3]);
        $customer = User::factory()->create(['is_featured' => true, 'featured_until' => now()->addDays(2)]);

        $this->artisan('featured:notify-expiring-soon')->assertSuccessful();

        $this->assertNotNull($customer->fresh()->featured_expiry_reminder_sent_at);
        $this->assertDatabaseHas('notifications', ['user_id' => $customer->id, 'type' => 'featured_expiring_soon']);
    }

    public function test_does_not_warn_a_customer_outside_the_window(): void
    {
        config(['featured.expiry_reminder_days_before' => 3]);
        $customer = User::factory()->create(['is_featured' => true, 'featured_until' => now()->addDays(10)]);

        $this->artisan('featured:notify-expiring-soon')->assertSuccessful();

        $this->assertNull($customer->fresh()->featured_expiry_reminder_sent_at);
        $this->assertDatabaseMissing('notifications', ['user_id' => $customer->id, 'type' => 'featured_expiring_soon']);
    }

    public function test_does_not_warn_a_customer_already_reminded(): void
    {
        config(['featured.expiry_reminder_days_before' => 3]);
        $customer = User::factory()->create(['is_featured' => true, 'featured_until' => now()->addDays(2)]);
        $customer->forceFill(['featured_expiry_reminder_sent_at' => now()->subHour()])->save();

        $this->artisan('featured:notify-expiring-soon')->assertSuccessful();

        $this->assertSame(0, Notification::where('type', 'featured_expiring_soon')->count());
    }

    public function test_does_not_warn_a_non_featured_customer(): void
    {
        config(['featured.expiry_reminder_days_before' => 3]);
        User::factory()->create(['is_featured' => false, 'featured_until' => now()->addDays(2)]);

        $this->artisan('featured:notify-expiring-soon')->assertSuccessful();

        $this->assertSame(0, Notification::where('type', 'featured_expiring_soon')->count());
    }

    public function test_warns_a_companys_owner_independently_of_any_user(): void
    {
        config(['featured.expiry_reminder_days_before' => 3]);
        $owner = User::factory()->create(['is_featured' => false]);
        $company = TransporterCompany::factory()->for($owner, 'owner')->create([
            'is_featured' => true, 'featured_until' => now()->addDay(),
        ]);

        $this->artisan('featured:notify-expiring-soon')->assertSuccessful();

        $this->assertNotNull($company->fresh()->featured_expiry_reminder_sent_at);
        $this->assertDatabaseHas('notifications', ['user_id' => $owner->id, 'type' => 'featured_expiring_soon']);
    }
}
