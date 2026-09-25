import 'package:cargo_motives/features/company/data/company_preferences_repository.dart';

class FakeCompanyPreferencesRepository extends CompanyPreferencesRepository {
  FakeCompanyPreferencesRepository({this.onUpdate});

  final Future<void> Function({
    bool? autoDeclineBelowBudget,
    double? floorRate,
    String? displayCurrency,
    bool? acceptingLoads,
  })?
  onUpdate;

  @override
  Future<void> update({bool? autoDeclineBelowBudget, double? floorRate, String? displayCurrency, bool? acceptingLoads}) {
    return onUpdate?.call(
          autoDeclineBelowBudget: autoDeclineBelowBudget,
          floorRate: floorRate,
          displayCurrency: displayCurrency,
          acceptingLoads: acceptingLoads,
        ) ??
        Future.value();
  }
}
