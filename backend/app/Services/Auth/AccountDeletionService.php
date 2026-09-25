<?php

namespace App\Services\Auth;

use App\Models\Bid;
use App\Models\DeviceToken;
use App\Models\Driver;
use App\Models\GpsConnection;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use App\Services\Documents\DocumentStorage;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * In-app account deletion (required by both app stores, and a data-subject
 * right under Tanzania's Personal Data Protection Act).
 *
 * Personal data is erased, not the rows that hold it: jobs, bids, payments
 * and reviews stay (anonymized) because the other party to a job, dispute
 * review and financial record-keeping all still depend on them — see the
 * Privacy Policy's "Data retention" section. The User row itself is
 * soft-deleted, which also makes it invisible to login and every
 * route-model binding.
 *
 * Refuses while the account still has obligations to someone else (an
 * open/in-progress job, a pending bid, an active assignment) — deleting
 * mid-delivery would strand the other party with no one to contact.
 */
class AccountDeletionService
{
    private const REDACTED = '[deleted]';

    private const FINISHED_STATUSES = ['completed', 'cancelled'];

    public function __construct(private readonly DocumentStorage $documents) {}

    /**
     * @throws ValidationException when the account still has open obligations
     */
    public function delete(User $user): void
    {
        $company = $user->transporterCompany;

        $this->assertNoOpenObligations($user, $company);

        $filesToDelete = [];

        DB::transaction(function () use ($user, $company, &$filesToDelete) {
            if ($company !== null) {
                $filesToDelete = [...$filesToDelete, ...$this->anonymizeCompany($company)];
            }

            $filesToDelete[] = $user->avatar_url;
            $filesToDelete[] = $user->company_logo_url;

            $user->tokens()->delete();
            DeviceToken::where('user_id', $user->id)->delete();

            $user->forceFill([
                'full_name' => null,
                'email' => null,
                // phone_number is NOT NULL + unique; a placeholder that can
                // never match a real (validated) phone number frees the
                // real one up for a future signup.
                'phone_number' => "deleted-{$user->id}",
                'password_hash' => null,
                'two_factor_enabled' => false,
                'avatar_url' => null,
                'company_name' => null,
                'company_logo_url' => null,
                'notification_preferences' => null,
                'is_featured' => false,
                'featured_until' => null,
            ])->save();

            $user->delete();
        });

        // Outside the transaction: a file delete can't be rolled back, so
        // it only happens once the database side has definitely committed.
        $this->documents->delete($filesToDelete);
    }

    private function assertNoOpenObligations(User $user, ?TransporterCompany $company): void
    {
        if ($user->account_type === 'customer'
            && Job::where('customer_id', $user->id)->whereNotIn('status', self::FINISHED_STATUSES)->exists()) {
            throw ValidationException::withMessages([
                'account' => ['You still have jobs that are open or in progress. Cancel or complete them before deleting your account.'],
            ]);
        }

        if ($company === null) {
            return;
        }

        if (Bid::where('transporter_company_id', $company->id)->where('status', 'pending')->exists()) {
            throw ValidationException::withMessages([
                'account' => ['You still have pending bids. Withdraw them before deleting your account.'],
            ]);
        }

        if (JobAward::where('transporter_company_id', $company->id)->whereNotIn('status', self::FINISHED_STATUSES)->exists()) {
            throw ValidationException::withMessages([
                'account' => ['You still have jobs in progress. Complete them before deleting your account.'],
            ]);
        }
    }

    /**
     * @return array<int, string|null> stored file keys to remove once committed
     */
    private function anonymizeCompany(TransporterCompany $company): array
    {
        $files = [$company->logo_url, $company->rep_id_document_url, $company->rep_selfie_url];
        $documents = $company->documents ?? [];
        array_walk_recursive($documents, function ($value) use (&$files) {
            $files[] = is_string($value) ? $value : null;
        });

        // Business identifiers (name, registration number, TIN) are kept:
        // they're business records rather than personal data, and duplicate
        // detection needs them to stop a banned company re-registering.
        $company->forceFill([
            'rep_full_name' => self::REDACTED,
            'rep_position' => self::REDACTED,
            'rep_national_id_number' => self::REDACTED,
            'rep_id_document_url' => '',
            'rep_selfie_url' => '',
            'company_phone' => self::REDACTED,
            'company_email' => null,
            'logo_url' => null,
            'documents' => null,
            'is_featured' => false,
            'featured_until' => null,
            'accepting_loads' => false,
        ])->save();

        foreach (Driver::where('transporter_company_id', $company->id)->get() as $driver) {
            $files[] = $driver->photo_url;
            $driver->forceFill([
                'full_name' => self::REDACTED,
                'phone_number' => self::REDACTED,
                'license_number' => null,
                'photo_url' => null,
                'is_active' => false,
            ])->save();
        }

        // Third-party GPS credentials must not outlive the account. Saved
        // per model (not a query-builder update) so the 'encrypted' cast
        // still applies — a raw '' would fail decryption on the next read.
        foreach (GpsConnection::where('transporter_company_id', $company->id)->get() as $connection) {
            $connection->forceFill(['access_token' => '', 'refresh_token' => null, 'status' => 'disconnected'])->save();
        }

        Truck::where('transporter_company_id', $company->id)->update([
            'is_active' => false,
            'gps_status' => 'not_connected',
        ]);

        return $files;
    }
}
