import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    // v21 uses named params
    await _plugin.initialize(settings: initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'fixed_expenses',
      'Gastos Fijos',
      channelDescription: 'Recordatorios de gastos fijos próximos a vencer',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> scheduleFixedExpenseReminder({
    required int id,
    required String name,
    required double amount,
    required int dayOfMonth,
    int daysBeforeAlert = 1,
  }) async {
    await init();
    final now = DateTime.now();
    var dueDate = DateTime(now.year, now.month, dayOfMonth);
    if (dueDate.isBefore(now)) {
      dueDate = DateTime(now.year, now.month + 1, dayOfMonth);
    }
    final alertDate = dueDate.subtract(Duration(days: daysBeforeAlert));
    if (alertDate.isBefore(now)) return;

    await _plugin.zonedSchedule(
      id: id,
      title: '⚠️ Vence mañana: $name',
      body: 'Pago de \$${amount.toStringAsFixed(0)} el día $dayOfMonth.',
      scheduledDate: tz.TZDateTime.from(alertDate, tz.local),
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> showInstantNotification(String title, String body) async {
    await init();
    await _plugin.show(
      id: 999,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'general',
          'General',
          channelDescription: 'Notificaciones generales',
        ),
      ),
    );
  }
}
