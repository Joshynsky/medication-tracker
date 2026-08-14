import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';
import 'services/notification_action_handler.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  // Created explicitly (rather than letting ProviderScope create its own)
  // so NotificationActionHandler can reach the app's real providers --
  // notification taps need to call the same confirmDose/snoozeDose logic
  // the UI uses, and keep the UI in sync if the app is already open.
  final container = ProviderContainer();

  await NotificationService.init(
    onNotificationResponse: (response) {
      NotificationActionHandler.handle(response, container);
    },
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: MeditrackApp(),
      ),
    ),
  );
}
