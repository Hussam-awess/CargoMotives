<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/**
 * A single Admin-editable business value (Backend Schema §2.17). Read
 * through App\Services\Settings\PlatformSettings, never queried directly by
 * feature code — that service owns caching and the typed get*() helpers.
 */
#[Fillable(['key', 'value', 'updated_by_admin_id'])]
class PlatformSetting extends Model {}
