import 'package:mezzome/features/dishes/data/models/production_plan_model.dart';

class ScheduleFetchResult {
  const ScheduleFetchResult({
    required this.items,
    this.isMenuCatalogFallback = false,
  });

  final List<ScheduledMenuItem> items;

  /// True when production plans are FORBIDDEN and owner menu catalog is shown.
  final bool isMenuCatalogFallback;
}
