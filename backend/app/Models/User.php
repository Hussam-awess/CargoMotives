<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * A logged-in participant: customer, transporter_company (the company's one
 * verified representative — Backend Schema §2.2), or admin. Drivers never
 * get a row here — they act only through a scoped Driver Link token
 * (PRD §5, TRD §7).
 */
#[Fillable(['account_type', 'phone_number', 'email', 'full_name', 'language_preference'])]
#[Hidden(['password_hash', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'password_hash' => 'hashed',
            'is_featured' => 'boolean',
            'featured_until' => 'datetime',
        ];
    }

    public function getAuthPassword(): ?string
    {
        return $this->password_hash;
    }
}
