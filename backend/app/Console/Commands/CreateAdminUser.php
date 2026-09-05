<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Auth\PhoneNumberNormalizer;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;
use InvalidArgumentException;

/**
 * Bootstraps the first Admin account. There's no Admin signup flow (Admin
 * gets its own small web tool in Phase 9 — PRD §10) — until then, this is
 * the only way to create one, deliberately kept to a CLI command rather
 * than an API endpoint (nothing should let an unauthenticated request
 * mint an Admin account).
 */
class CreateAdminUser extends Command
{
    protected $signature = 'admin:create {phone : E.g. 0712345678 or +255712345678} {email} {password}';

    protected $description = 'Create an Admin user (email+password login, used by /api/admin/login)';

    public function handle(): int
    {
        $validator = Validator::make($this->arguments(), [
            'phone' => ['required', 'string'],
            'email' => ['required', 'email'],
            'password' => ['required', 'string', 'min:8'],
        ]);

        if ($validator->fails()) {
            $this->error($validator->errors()->first());

            return self::FAILURE;
        }

        try {
            $phone = PhoneNumberNormalizer::normalize($this->argument('phone'));
        } catch (InvalidArgumentException $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        if (User::where('phone_number', $phone)->orWhere('email', $this->argument('email'))->exists()) {
            $this->error('A user with that phone number or email already exists.');

            return self::FAILURE;
        }

        $admin = new User([
            'account_type' => 'admin',
            'phone_number' => $phone,
            'email' => $this->argument('email'),
            'full_name' => 'Admin',
        ]);

        // password_hash is deliberately excluded from User::$fillable (it's
        // security-sensitive — no request path should ever be able to mass-
        // assign it), so it's set directly here rather than passed to
        // create(). Direct property assignment still goes through
        // User::casts()'s 'hashed' cast, which hashes this plain value
        // automatically on save.
        $admin->password_hash = $this->argument('password');
        $admin->save();

        $this->info("Admin created: {$this->argument('email')}");

        return self::SUCCESS;
    }
}
