<?php

namespace App\Models;

use Database\Factories\DeviceTokenFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One registered FCM token for one device install (new table — see this
 * migration's docblock). Always written through
 * NotificationController::registerDeviceToken()'s updateOrCreate(by token),
 * never Model::create() directly, so re-registering the same token (app
 * reinstall, token refresh, or a different account signing in on the same
 * physical device) updates the existing row instead of accumulating stale
 * duplicates.
 */
#[Fillable(['user_id', 'token', 'platform'])]
class DeviceToken extends Model
{
    /** @use HasFactory<DeviceTokenFactory> */
    use HasFactory;

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
