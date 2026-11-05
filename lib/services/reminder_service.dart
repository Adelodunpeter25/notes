import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/daos.dart';
import '../utils/note.dart';

/// How often a reminder repeats.
enum ReminderRepeat { none, daily, weekly, monthly }

extension ReminderRepeatX on ReminderRepeat {
  String get storageValue => name;

  String get label => switch (this) {
        ReminderRepeat.none => 'Never',
        ReminderRepeat.daily => 'Daily',
        ReminderRepeat.weekly => 'Weekly',
        ReminderRepeat.monthly => 'Monthly',
      };

  static ReminderRepeat fromStorage(String value) => ReminderRepeat.values
      .firstWhere((r) => r.name == value, orElse: () => ReminderRepeat.none);

  DateTime occurrenceAfter(DateTime start, int occurrences) => switch (this) {
        ReminderRepeat.none => start,
        ReminderRepeat.daily => start.add(Duration(days: occurrences)),
        ReminderRepeat.weekly => start.add(Duration(days: 7 * occurrences)),
        ReminderRepeat.monthly => _addMonths(start, occurrences),
      };

  /// Adds [months] whole months, clamping the day to the month's last day
  /// (Jan 31 + 1 month lands on Feb 28, not Mar 3).
  static DateTime _addMonths(DateTime start, int months) {
    final totalMonths = start.month - 1 + months;
    final year = start.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = start.day > lastDayOfMonth ? lastDayOfMonth : start.day;
    return DateTime(year, month, day, start.hour, start.minute);
  }
}

/// Schedules local note reminders as OS notifications.
///
/// Reminders are device-local by design: they live in the `reminders` drift
/// table, are never pushed to the server, and never appear in the sync queue.
/// When a reminder fires, the notification shows the note snapshot (title and
/// plain-text content) captured when the reminder was scheduled.
///
/// Every occurrence is scheduled up front (Android alarms are persisted by the
/// flutter_local_notifications plugin and restored after reboot), and all
/// reminders are re-scheduled on every app start so nothing goes stale.
class ReminderService {
  ReminderService(this.db) : dao = ReminderDao(db);

  final AppDatabase db;
  final ReminderDao dao;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Android notification ids for one reminder: `baseId(reminder.id) + index`.
  static const int _maxScheduledOccurrences = 100;
  static const String _channelId = 'note_reminders';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tzdata.initializeTimeZones();
    final timeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Android 13+ requires the notification permission to be requested at runtime.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// The reminder attached to a note, if any.
  Future<Reminder?> reminderForNote(String noteId) => dao.forNote(noteId);

  /// Schedules (or replaces) the reminder for a note and persists it locally.
  ///
  /// A non-repeating reminder fires once at [scheduledAt]. A repeating one
  /// fires [repeatCount] occurrences spaced one [repeat] apart, each showing
  /// the note's content snapshot.
  Future<void> scheduleReminder({
    required Note note,
    required DateTime scheduledAt,
    required ReminderRepeat repeat,
    required int? repeatCount,
  }) async {
    await initialize();

    final reminderId = const Uuid().v4();
    final reminder = Reminder(
      id: reminderId,
      noteId: note.id,
      userId: note.userId,
      scheduledAt: scheduledAt,
      repeatInterval: repeat.storageValue,
      repeatCount: repeat == ReminderRepeat.none ? null : repeatCount,
      title: _snapshotTitle(note),
      body: _snapshotBody(note),
      createdAt: DateTime.now(),
    );

    // Replace any reminder already attached to this note.
    await cancelReminderForNote(note.id);

    await dao.insertReminder(RemindersCompanion.insert(
      id: reminder.id,
      noteId: reminder.noteId,
      userId: reminder.userId,
      scheduledAt: reminder.scheduledAt,
      repeatInterval: reminder.repeatInterval,
      repeatCount: Value(reminder.repeatCount),
      title: reminder.title,
      body: reminder.body,
    ));

    await _scheduleOccurrences(reminder);
  }

  /// Cancels a note's reminder notifications and deletes its local row.
  Future<void> cancelReminderForNote(String noteId) async {
    final existing = await dao.forNote(noteId);
    if (existing == null) return;
    await _cancelNotifications(existing);
    await dao.deleteForNote(noteId);
  }

  /// Startup maintenance: drops reminders whose note is gone and re-schedules
  /// every future occurrence (covers reboots and cleared plugin storage).
  Future<void> rescheduleAll() async {
    await initialize();
    await dao.deleteOrphaned();

    final now = DateTime.now();
    for (final reminder in await dao.all()) {
      await _cancelNotifications(reminder);
      await _scheduleOccurrences(reminder, from: now);
    }
  }

  Future<void> _scheduleOccurrences(Reminder reminder, {DateTime? from}) async {
    final repeat = ReminderRepeatX.fromStorage(reminder.repeatInterval);
    final totalOccurrences = repeat == ReminderRepeat.none
        ? 1
        : (reminder.repeatCount ?? 1).clamp(1, _maxScheduledOccurrences);

    final notBefore =
        from ?? DateTime.now().subtract(const Duration(seconds: 1));
    var scheduled = 0;
    for (var i = 0;
        i < totalOccurrences && scheduled < _maxScheduledOccurrences;
        i++) {
      final occurrence = repeat.occurrenceAfter(reminder.scheduledAt, i);
      if (occurrence.isBefore(notBefore)) continue;
      await _scheduleNotification(
          _notificationId(reminder.id, scheduled), occurrence, reminder);
      scheduled++;
    }
  }

  Future<void> _scheduleNotification(
      int id, DateTime when, Reminder reminder) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Note reminders',
        channelDescription: 'Reminders for your notes',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final scheduledDate = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Exact alarms can be unavailable (Android 12+ without the alarm
      // permission); fall back to the window the OS allows.
      await _plugin.zonedSchedule(
        id: id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _cancelNotifications(Reminder reminder) async {
    for (var i = 0; i < _maxScheduledOccurrences; i++) {
      await _plugin.cancel(id: _notificationId(reminder.id, i));
    }
  }

  int _notificationId(String reminderId, int index) =>
      (reminderId.hashCode & 0x7FFFFFFF) + index;

  String _snapshotTitle(Note note) {
    final title = note.title.isNotEmpty
        ? note.title
        : NoteUtils.titleFromContent(note.content);
    return title.isEmpty ? 'Note reminder' : title;
  }

  String _snapshotBody(Note note) {
    final lines = NoteUtils.extractLines(note.content)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    final body =
        lines.skip(1).isNotEmpty ? lines.skip(1).join(' ') : lines.join(' ');
    if (body.isEmpty) return 'Reminder for your note';
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }
}
