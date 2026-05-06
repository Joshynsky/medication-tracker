import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  tz.initializeTimeZones();
  await NotificationService.init();
  
  runApp(
    const ProviderScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MeditrackApp(),
      ),
    ),
  );
}
