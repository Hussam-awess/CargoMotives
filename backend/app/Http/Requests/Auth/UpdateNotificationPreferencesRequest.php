<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * A partial map — {"bids": false} on its own is valid — since Settings
 * toggles save one category at a time, not the whole set. Absent keys are
 * left untouched (ProfileController::updateNotificationPreferences merges
 * rather than replaces).
 */
class UpdateNotificationPreferencesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'bids' => ['sometimes', 'boolean'],
            'shipment_updates' => ['sometimes', 'boolean'],
            'messages' => ['sometimes', 'boolean'],
            'new_job_matches' => ['sometimes', 'boolean'],
            'sms_alerts' => ['sometimes', 'boolean'],
            'promotions' => ['sometimes', 'boolean'],
        ];
    }
}
