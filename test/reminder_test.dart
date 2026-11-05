import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:note/database/database.dart';
import 'package:note/database/daos.dart';
import 'package:note/services/reminder_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('reminder repeat intervals produce spaced occurrences', () {
    final start = DateTime(2026, 1, 31, 9, 0);

    expect(
      ReminderRepeat.none.occurrenceAfter(start, 5),
      start,
    );
    expect(
      ReminderRepeat.daily.occurrenceAfter(start, 3),
      DateTime(2026, 2, 3, 9, 0),
    );
    expect(
      ReminderRepeat.weekly.occurrenceAfter(start, 2),
      DateTime(2026, 2, 14, 9, 0),
    );
    // Monthly stepping keeps the time-of-day and skips through months.
    expect(
      ReminderRepeat.monthly.occurrenceAfter(start, 1),
      DateTime(2026, 2, 28, 9, 0), // Feb 2026 has 28 days: 31 -> clamps
    );
  });

  test('reminder round-trips through the local database, never synced',
      () async {
    final users = db.users;
    await db.into(users).insert(UsersCompanion.insert(
          id: 'u1',
          username: 'peter',
          email: 'peter@example.com',
        ));
    final notes = db.notes;
    const noteId = 'n1';
    await db.into(notes).insert(NotesCompanion.insert(
          id: noteId,
          title: 'Shopping list',
          content: '{"document":{}}',
          userId: 'u1',
        ));

    final dao = ReminderDao(db);
    await dao.insertReminder(RemindersCompanion.insert(
      id: 'r1',
      noteId: noteId,
      userId: 'u1',
      scheduledAt: DateTime(2026, 11, 10, 9, 0),
      repeatInterval: 'weekly',
      repeatCount: const Value(4),
      title: 'Shopping list',
      body: 'milk, eggs',
    ));

    final loaded = await dao.forNote(noteId);
    expect(loaded, isNotNull);
    expect(loaded!.repeatInterval, 'weekly');
    expect(loaded.repeatCount, 4);
    expect(ReminderRepeatX.fromStorage(loaded.repeatInterval),
        ReminderRepeat.weekly);

    // Deleting the note makes the reminder orphaned; startup cleanup drops it.
    await (db.delete(notes)..where((t) => t.id.equals(noteId))).go();
    expect(await dao.deleteOrphaned(), 1);
    expect(await dao.forNote(noteId), isNull);
  });
}
