<?php

namespace Tests\Unit\Services\Jobs;

use App\Models\Bid;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\Notification;
use App\Models\User;
use App\Services\Geo\GeoPoint;
use App\Services\Jobs\JobStatusAutoAdvancer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * A driver's own manual tap on the Driver Link page reaches the exact same
 * ->update(['status' => ...]) call this service makes, so the resulting
 * notification is already covered by NotificationTriggersTest — these
 * tests are purely about the geofencing *decision itself*: does this
 * status, at this distance, cross the configured threshold or not.
 */
class JobStatusAutoAdvancerTest extends TestCase
{
    use RefreshDatabase;

    private const PICKUP = ['lat' => -6.8161, 'lng' => 39.2803];

    private const DROPOFF = ['lat' => -6.9, 'lng' => 39.35];

    private function advancer(): JobStatusAutoAdvancer
    {
        return $this->app->make(JobStatusAutoAdvancer::class);
    }

    /**
     * Job::withCoordinates() only adds the select when the query itself
     * runs it — a plain ::create() bypasses that, so this re-fetches
     * through the scope the same way NormalizeGpsPositionJob does.
     */
    private function loadWithCoordinates(Job $job): Job
    {
        return Job::withCoordinates()->findOrFail($job->id);
    }

    public function test_the_first_ping_on_an_assigned_job_advances_to_en_route_pickup(): void
    {
        $job = $this->loadWithCoordinates(Job::factory()->create(['status' => 'assigned']));

        $this->advancer()->advance($job, $job, new GeoPoint(-20.0, 50.0));

        $this->assertSame('en_route_pickup', $job->fresh()->status);
    }

    public function test_far_from_pickup_stays_en_route(): void
    {
        $job = $this->makeJob('en_route_pickup');

        // ~100km away — nowhere near the 0.5km default arrival radius.
        $this->advancer()->advance($job, $job, new GeoPoint(-7.7, 39.2803));

        $this->assertSame('en_route_pickup', $job->fresh()->status);
    }

    public function test_within_the_arrival_radius_of_pickup_advances_to_picked_up(): void
    {
        $job = $this->makeJob('en_route_pickup');

        $this->advancer()->advance($job, $job, new GeoPoint(self::PICKUP['lat'], self::PICKUP['lng']));

        $this->assertSame('picked_up', $job->fresh()->status);
    }

    public function test_still_near_pickup_after_being_picked_up_stays_picked_up(): void
    {
        $job = $this->makeJob('picked_up');

        $this->advancer()->advance($job, $job, new GeoPoint(self::PICKUP['lat'], self::PICKUP['lng']));

        $this->assertSame('picked_up', $job->fresh()->status);
    }

    public function test_beyond_the_departure_radius_from_pickup_advances_to_in_transit(): void
    {
        $job = $this->makeJob('picked_up');

        // ~13km from pickup — past the 5km default departure radius.
        $this->advancer()->advance($job, $job, new GeoPoint(-6.9, 39.2803));

        $this->assertSame('in_transit', $job->fresh()->status);
    }

    public function test_arriving_at_dropoff_notifies_once_and_never_sets_delivered(): void
    {
        $customer = User::factory()->create();
        $job = $this->makeJob('in_transit', $customer);

        $this->advancer()->advance($job, $job, new GeoPoint(self::DROPOFF['lat'], self::DROPOFF['lng']));

        $job->refresh();
        $this->assertSame('in_transit', $job->status);
        $this->assertNotNull($job->dropoff_arrival_notified_at);
        $this->assertDatabaseHas('notifications', ['user_id' => $customer->id, 'type' => 'job_arrived_at_dropoff']);
    }

    public function test_a_second_ping_at_dropoff_does_not_notify_again(): void
    {
        $customer = User::factory()->create();
        $job = $this->makeJob('in_transit', $customer);
        $atDropoff = new GeoPoint(self::DROPOFF['lat'], self::DROPOFF['lng']);

        $this->advancer()->advance($job, $job, $atDropoff);
        $this->advancer()->advance($job->fresh(), $job->fresh(), $atDropoff);

        $this->assertSame(1, Notification::where('type', 'job_arrived_at_dropoff')->count());
    }

    public function test_far_from_dropoff_does_not_notify(): void
    {
        $job = $this->makeJob('in_transit');

        $this->advancer()->advance($job, $job, new GeoPoint(self::PICKUP['lat'], self::PICKUP['lng']));

        $this->assertNull($job->fresh()->dropoff_arrival_notified_at);
        $this->assertDatabaseMissing('notifications', ['type' => 'job_arrived_at_dropoff']);
    }

    public function test_a_delivered_or_completed_job_is_left_alone(): void
    {
        $job = $this->makeJob('delivered');

        $this->advancer()->advance($job, $job, new GeoPoint(self::DROPOFF['lat'], self::DROPOFF['lng']));

        $this->assertSame('delivered', $job->fresh()->status);
        $this->assertNull($job->fresh()->dropoff_arrival_notified_at);
    }

    /**
     * Tier 3: the award is the status holder, but pickup/dropoff always
     * come from the parent job — the same $award->job relation
     * NormalizeGpsPositionJob's own award branch passes in.
     */
    public function test_an_awards_status_advances_independently_of_the_job(): void
    {
        $job = $this->makeJob('open');
        $bid = Bid::factory()->for($job)->create();
        $award = JobAward::create([
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $bid->transporter_company_id,
            'trucks_offered' => $bid->trucks_offered,
            'agreed_price' => $bid->price,
            'status' => 'en_route_pickup',
        ]);

        $this->advancer()->advance($award, $job, new GeoPoint(self::PICKUP['lat'], self::PICKUP['lng']));

        $this->assertSame('picked_up', $award->fresh()->status);
        $this->assertSame('open', $job->fresh()->status);
    }

    private function makeJob(string $status, ?User $customer = null): Job
    {
        $job = Job::factory()->create([
            'status' => $status,
            ...($customer !== null ? ['customer_id' => $customer->id] : []),
            'pickup_location' => (new GeoPoint(self::PICKUP['lat'], self::PICKUP['lng']))->toInsertExpression(),
            'dropoff_location' => (new GeoPoint(self::DROPOFF['lat'], self::DROPOFF['lng']))->toInsertExpression(),
        ]);

        return $this->loadWithCoordinates($job);
    }
}
