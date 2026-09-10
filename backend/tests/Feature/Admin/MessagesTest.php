<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Messages\Index;
use App\Models\SupportMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class MessagesTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_finds_a_user_by_name(): void
    {
        $admin = User::factory()->admin()->create();
        User::factory()->create(['full_name' => 'Amina Juma']);
        User::factory()->create(['full_name' => 'Someone Else']);

        Livewire::actingAs($admin)->test(Index::class)
            ->set('query', 'Amina')
            ->assertSee('Amina Juma')->assertDontSee('Someone Else');
    }

    public function test_selecting_a_user_shows_their_existing_thread(): void
    {
        $admin = User::factory()->admin()->create();
        $customer = User::factory()->create(['full_name' => 'Amina Juma']);
        SupportMessage::factory()->create(['user_id' => $customer->id, 'body' => 'How do I change my payout method?']);

        Livewire::actingAs($admin)->test(Index::class)
            ->call('selectUser', $customer->id)
            ->assertSee('How do I change my payout method?');
    }

    public function test_sending_to_one_selected_user_creates_exactly_one_message(): void
    {
        $admin = User::factory()->admin()->create();
        $customer = User::factory()->create();
        $otherCustomer = User::factory()->create();

        Livewire::actingAs($admin)->test(Index::class)
            ->call('selectUser', $customer->id)
            ->set('body', 'Thanks for reaching out, we are looking into it.')
            ->call('send');

        $this->assertDatabaseHas('support_messages', [
            'user_id' => $customer->id,
            'author' => 'admin',
            'admin_id' => $admin->id,
            'body' => 'Thanks for reaching out, we are looking into it.',
        ]);
        $this->assertDatabaseMissing('support_messages', ['user_id' => $otherCustomer->id]);
    }

    public function test_broadcasting_to_all_customers_creates_one_message_per_customer_and_skips_companies(): void
    {
        $admin = User::factory()->admin()->create();
        User::factory()->count(3)->create(['account_type' => 'customer']);
        User::factory()->transporterCompany()->create();

        Livewire::actingAs($admin)->test(Index::class)
            ->call('selectBroadcast', 'customer')
            ->set('body', 'Scheduled maintenance tonight.')
            ->call('send');

        $this->assertSame(3, SupportMessage::where('body', 'Scheduled maintenance tonight.')->count());
    }

    public function test_cannot_send_without_choosing_a_recipient(): void
    {
        $admin = User::factory()->admin()->create();

        Livewire::actingAs($admin)->test(Index::class)
            ->set('body', 'Hello?')
            ->call('send')
            ->assertHasErrors('body');

        $this->assertDatabaseCount('support_messages', 0);
    }

    public function test_a_non_admin_cannot_access_the_page(): void
    {
        $customer = User::factory()->create();

        $this->actingAs($customer)->get('/admin/messages')->assertForbidden();
    }
}
