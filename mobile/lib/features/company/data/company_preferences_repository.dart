import '../../../core/network/api_client.dart';

/// Small standalone company preferences — see the backend
/// CompanyPreferencesController's own docblock for what each one does.
/// Returns nothing: callers already have a `CompanyFeaturedStatus` fetch
/// (`/company/featured/status`) that carries these same fields for
/// re-reading, so a round-trip re-fetch after saving is cheap and reuses
/// existing code rather than parsing a second response shape.
class CompanyPreferencesRepository {
  CompanyPreferencesRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> update({
    bool? autoDeclineBelowBudget,
    double? floorRate,
    String? displayCurrency,
    bool? acceptingLoads,
  }) {
    return _client.post(
      '/company/preferences',
      data: {
        if (autoDeclineBelowBudget != null) 'auto_decline_below_budget': autoDeclineBelowBudget,
        if (floorRate != null) 'floor_rate': floorRate,
        if (displayCurrency != null) 'display_currency': displayCurrency,
        if (acceptingLoads != null) 'accepting_loads': acceptingLoads,
      },
    );
  }
}
