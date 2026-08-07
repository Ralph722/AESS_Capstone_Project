import 'package:flutter/foundation.dart';

/// Broadcasts when the admin survey catalog changes (create, publish, close, delete).
class SurveyCatalogRefresh {
  SurveyCatalogRefresh._();

  static final SurveyCatalogRefresh instance = SurveyCatalogRefresh._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notifyChanged() {
    revision.value++;
  }
}
