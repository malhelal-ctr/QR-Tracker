import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/lid_forecast.dart';
import '../data/stock_stats.dart';
import '../data/tracker_repository.dart';
import '../utils/format.dart';

/// One planned low-stock notification.
typedef LidAlert = ({DateTime at, String title, String body});

/// The low-stock notifications to plan from [stock]: one at [notifyAt] (minutes after midnight) on each
/// working day from the first low day, up to [max]. A first one whose time has already passed today
/// is kept with that time, so the caller can show it straight away.
List<LidAlert> plannedLidAlerts({
  required StockStats stock,
  required bool Function(String date) isOff,
  required int notifyAt,
  required DateTime now,
  int max = 10,
}) {
  final f = stock.forecast;
  if (!stock.hasData || f == null) return const [];
  final today = DateTime(now.year, now.month, now.day);
  // the first low day: today when it is low already, else the order-by day
  final DateTime? first = stock.isLow ? today : f.orderBy;
  if (first == null) return const [];

  final alerts = <LidAlert>[];
  for (var i = 0; i < 60 && alerts.length < max; i++) {
    final day = DateTime(first.year, first.month, first.day + i);
    if (day.isBefore(today) || isOff(ymd(day))) continue;
    final at = day.add(Duration(minutes: notifyAt));
    final left = day == today ? f.onHand : f.leftAtStartOf(day);
    alerts.add((at: at, title: left <= 0 ? 'Out of lids' : 'Lid stock low', body: _body(f, left)));
  }
  return alerts;
}

String _body(LidForecast f, int left) {
  if (left <= 0) return 'No lids left. Log a delivery or a stock count when new lids arrive.';
  final runOut = f.runOut == null ? '' : ', runs out ${fmtDate(f.runOut!)}';
  final rate = f.average == null ? '' : ' (at your average ${fmt(f.average)}/day)';
  return '${fmt(left)} lids left$runOut$rate. Order new lids now.';
}

/// Keeps the phone's low-stock notifications in step with the data: every change re-plans them.
/// Android only; does nothing on the web.
class LidNotifier {
  LidNotifier(this._repository);

  final TrackerRepository _repository;
  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _debounce;
  bool _asked = false;

  static const _channel = AndroidNotificationDetails(
    'lid_stock',
    'Lid stock',
    channelDescription: 'Reminders when lid stock is low',
    importance: Importance.high,
    priority: Priority.high,
  );

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> start() async {
    if (!supported) return;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    } catch (e) {
      debugPrint('Lid notifications unavailable: $e');
      return;
    }
    _repository.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 1), _reschedule);
    });
    await _reschedule();
  }

  Future<void> _reschedule() async {
    try {
      await _plugin.cancelAll();
      if (!_repository.lidNotify) return;
      final now = DateTime.now();
      final alerts = plannedLidAlerts(stock: _repository.stock, isOff: _repository.isOff, notifyAt: _repository.lidNotifyAt, now: now);
      if (alerts.isEmpty) return;

      // ask for the permission once, the first time there is something to show
      if (!_asked) {
        _asked = true;
        await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      }

      const details = NotificationDetails(android: _channel);
      for (final (i, a) in alerts.indexed) {
        if (a.at.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: 100 + i,
            scheduledDate: tz.TZDateTime.from(a.at, tz.local),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: a.title,
            body: a.body,
          );
        } else if (_repository.lidNotifiedOn != ymd(now)) {
          // today's time has passed: show it now, once a day
          await _plugin.show(id: 99, title: a.title, body: a.body, notificationDetails: details);
          await _repository.setLidNotifiedOn(ymd(now));
        }
      }
    } catch (e) {
      debugPrint('Could not plan lid notifications: $e');
    }
  }
}
