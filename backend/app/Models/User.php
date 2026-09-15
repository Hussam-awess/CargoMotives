<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
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
#[Fillable([
    'account_type', 'phone_number', 'email', 'full_name', 'avatar_url', 'language_preference', 'is_featured', 'featured_until',
    'company_name', 'company_logo_url', 'email_verified_at', 'notification_preferences', 'last_active_at', 'last_inactivity_nudge_at',
])]
#[Hidden(['password_hash', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    /**
     * Mirrors the migration's column defaults. Eloquent's create() does NOT
     * reflect DB-level ->default(...) values on the in-memory model it
     * returns — only what's explicitly passed to create(), or declared
     * here, shows up immediately (a real bug this caught in Phase 3: a
     * fresh Truck's gps_status/current_status/is_active were null in the
     * API response despite having DB defaults, because nothing set them
     * explicitly and nothing had declared them here either).
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        'status' => 'active',
        // English default (deliberate product decision, overriding the
        // docs' original "Swahili default" — see LocaleController on the
        // Flutter side for the matching change).
        'language_preference' => 'en',
        'is_featured' => false,
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'password_hash' => 'hashed',
            'is_featured' => 'boolean',
            'featured_until' => 'datetime',
            'email_verified_at' => 'datetime',
            'notification_preferences' => 'array',
            'last_active_at' => 'datetime',
            'last_inactivity_nudge_at' => 'datetime',
        ];
    }

    public function getAuthPassword(): ?string
    {
        return $this->password_hash;
    }

    /**
     * Opt-out, not opt-in: an absent key (the default for every user who's
     * never touched a Settings toggle) means "on", so NotificationService
     * still delivers everything the trigger map promises out of the box.
     */
    public function wantsNotificationCategory(string $category): bool
    {
        return (bool) ($this->notification_preferences[$category] ?? true);
    }

    public function transporterCompany(): HasOne
    {
        return $this->hasOne(TransporterCompany::class, 'owner_user_id');
    }

    public function jobs(): HasMany
    {
        return $this->hasMany(Job::class, 'customer_id');
    }
}
