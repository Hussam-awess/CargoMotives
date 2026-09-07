<?php

namespace Tests\Unit\Services\Push;

use App\Services\Push\Drivers\FirebasePushDriver;
use Tests\TestCase;

class FirebasePushDriverTest extends TestCase
{
    public function test_it_fails_gracefully_when_no_credentials_are_configured(): void
    {
        config(['fcm.credentials_path' => null]);

        $result = (new FirebasePushDriver)->send(['a-token'], 'Title', 'Body');

        $this->assertFalse($result->successful);
        $this->assertNotNull($result->error);
    }

    public function test_it_fails_gracefully_when_the_credentials_file_does_not_exist(): void
    {
        config(['fcm.credentials_path' => '/nonexistent/service-account.json']);

        $result = (new FirebasePushDriver)->send(['a-token'], 'Title', 'Body');

        $this->assertFalse($result->successful);
        $this->assertNotNull($result->error);
    }

    public function test_an_empty_token_list_is_a_no_op_success(): void
    {
        $result = (new FirebasePushDriver)->send([], 'Title', 'Body');

        $this->assertTrue($result->successful);
    }
}
