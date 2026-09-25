<?php

namespace App\Http\Resources;

use App\Models\TransporterCompany;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin TransporterCompany
 */
class CompanyResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $storage = app(DocumentStorage::class);

        return [
            'id' => $this->id,
            'company_name' => $this->company_name,
            'registration_number' => $this->registration_number,
            'tin' => $this->tin,
            'physical_address' => $this->physical_address,
            'physical_lat' => $this->physical_lat,
            'physical_lng' => $this->physical_lng,
            'company_phone' => $this->company_phone,
            'company_email' => $this->company_email,
            // Every *_url / documents value below is a private storage key
            // on the model, signed into a short-lived URL only here at
            // response time — see DocumentStorage's docblock for why.
            'logo_url' => $this->logo_url ? $storage->signedUrl($this->logo_url) : null,
            // Most entries are a single storage key; 'other_documents' is
            // the one that can be a list (Phase 10.7 — "other required
            // transport/business documents" is explicitly plural) — signed
            // per-item either way.
            'documents' => collect($this->documents ?? [])
                ->map(fn ($value) => is_array($value)
                    ? collect($value)->map(fn (string $key) => $storage->signedUrl($key))->all()
                    : $storage->signedUrl($value))
                ->all(),
            'rep_full_name' => $this->rep_full_name,
            'rep_position' => $this->rep_position,
            'rep_national_id_number' => $this->rep_national_id_number,
            'rep_id_document_url' => $storage->signedUrl($this->rep_id_document_url),
            // No longer collected (Phase 13) — nullable on existing rows too.
            'rep_selfie_url' => $this->rep_selfie_url ? $storage->signedUrl($this->rep_selfie_url) : null,
            'verification_status' => $this->verification_status,
            'verification_rejected_reason' => $this->verification_rejected_reason,
            // Why CompanyAutoVerifier held this instead of approving it
            // outright — the transporter needs this to know what to fix
            // before resubmitting, same as the Admin queue shows it.
            'auto_check_notes' => $this->auto_check_notes,
            'verified_at' => $this->verified_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'auto_decline_below_budget' => (bool) $this->auto_decline_below_budget,
            'floor_rate' => $this->floor_rate !== null ? (float) $this->floor_rate : null,
            'floor_rate_currency' => $this->floor_rate_currency,
            'display_currency' => $this->display_currency,
            'accepting_loads' => (bool) $this->accepting_loads,
        ];
    }
}
