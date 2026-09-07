<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Phase 10 launch prep: both app stores require a hosted privacy-policy
 * URL at submission.
 */
class LegalPagesTest extends TestCase
{
    public function test_the_privacy_policy_page_loads(): void
    {
        $this->get('/legal/privacy')->assertOk()->assertSee('Privacy Policy');
    }

    public function test_the_terms_page_loads(): void
    {
        $this->get('/legal/terms')->assertOk()->assertSee('Terms of Service');
    }
}
