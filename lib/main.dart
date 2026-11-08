import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/gateway_dashboard.dart';
import 'services/polling_service.dart';
import 'services/sms_listener.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ensureSupabaseInitialized();

  await [
    Permission.sms,
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
  ].request();

  await initializeGateway();

  runApp(const MyApp());
}

Future<void> initializeGateway() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackground,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      initialNotificationTitle: 'Lango SMS Gateway',
      initialNotificationContent: 'Listening for messages...',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: const [AndroidForegroundType.specialUse],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onBackground,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
Future<void> onBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await ensureSupabaseInitialized();

  service.on('stopService').listen((_) => service.stopSelf());

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      unawaited(service.setAsForegroundService());
    });
    service.on('setAsBackground').listen((_) {
      unawaited(service.setAsBackgroundService());
    });

    Future<void> updateNotification() async {
      if (!await service.isForegroundService()) return;

      await service.setForegroundNotificationInfo(
        title: 'Lango SMS Gateway',
        content:
            'Service active - ${DateTime.now().toLocal().toString().split('.')[0]}',
      );
    }

    unawaited(updateNotification());
    Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(updateNotification());
    });
  }

  SmsListener().startListening();
  PollingService().startPolling();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lango SMS Gateway',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      home: const GatewayDashboard(),
    );
  }
}
