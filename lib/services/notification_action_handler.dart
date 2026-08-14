import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';

/// Handles a tap on a notification or one of its action buttons
/// ("I took them" / "Snooze"). Both actions are foreground
/// (showsUserInterface: true), so this always runs in the same, already-
/// initialized Flutter engine/isolate as the rest of the app -- there's no
/// separate background-isolate handling to worry about here.
///
/// Reuses the exact same confirm/snooze logic the Dashboard's own "Take"
/// and "Snooze" buttons call (DashboardNotifier.confirmDose/snoozeDose),
/// via the app's real ProviderContainer (see main.dart) -- not a separate
/// database connection -- so the UI stays in sync if the app happens to
/// already be open when the action fires.
class NotificationActionHandler {
  NotificationActionHandler._();

  static Future<void> handle(
    NotificationResponse response,
    ProviderContainer container,
  ) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      data = decoded;
    } on FormatException {
      return;
    }

    final medicationId = data['medicationId'] as int?;
    final doseId = data['doseId'] as int?;
    if (medicationId == null || doseId == null) return;

    switch (response.actionId) {
      case 'take_dose':
        await container
            .read(dashboardProvider.notifier)
            .confirmDose(doseId, medicationId);
      case 'snooze_dose':
        await container.read(dashboardProvider.notifier).snoozeDose(doseId);
      default:
        // A plain tap on the notification body (no action button) just
        // opens the app to the Dashboard, which already happens by
        // default -- nothing else to do.
        break;
    }
  }
}
