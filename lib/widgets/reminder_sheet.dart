import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../database/database.dart' hide User;
import '../services/reminder_service.dart';
import '../theme.dart';
import 'service_provider.dart';

/// Opens the "Remind me" sheet for a note: date, time, repeat interval and
/// how many times the reminder should fire. Replaces any existing reminder.
Future<void> showReminderSheet(BuildContext context, Note note) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppSurfaces.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReminderSheet(note: note),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.note});

  final Note note;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  Reminder? _existing;

  late DateTime _when = DateTime.now().add(const Duration(hours: 1));
  ReminderRepeat _repeat = ReminderRepeat.none;
  int _repeatCount = 3;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final services = ServiceProvider.of(context);
    final existing =
        await services.reminderService.reminderForNote(widget.note.id);
    if (!mounted || existing == null) return;
    setState(() {
      _existing = existing;
      _when = existing.scheduledAt;
      _repeat = ReminderRepeatX.fromStorage(existing.repeatInterval);
      _repeatCount = existing.repeatCount ?? _repeatCount;
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _when =
          DateTime(date.year, date.month, date.day, _when.hour, _when.minute);
    });
    _pickTime();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (time == null || !mounted) return;
    setState(() {
      _when =
          DateTime(_when.year, _when.month, _when.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final services = ServiceProvider.of(context);
    await services.reminderService.scheduleReminder(
      note: widget.note,
      scheduledAt: _when,
      repeat: _repeat,
      repeatCount: _repeatCount,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _remove() async {
    final services = ServiceProvider.of(context);
    await services.reminderService.cancelReminderForNote(widget.note.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  String _formatWhen(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(when.year, when.month, when.day);
    final day = target == today
        ? 'Today'
        : target == today.add(const Duration(days: 1))
            ? 'Tomorrow'
            : '${target.day}/${target.month}/${target.year}';
    final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    final amPm = when.hour < 12 ? 'AM' : 'PM';
    return '$day, $hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Remind me',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTextColors.primary(context),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(CupertinoIcons.calendar, color: AppColors.accent),
            title: Text(_formatWhen(_when),
                style: TextStyle(color: AppTextColors.primary(context))),
            trailing: const Icon(CupertinoIcons.chevron_down,
                size: 14, color: AppColors.accent),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          Text(
            'Repeat',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTextColors.secondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final repeat in ReminderRepeat.values)
                ChoiceChip(
                  label: Text(repeat.label),
                  selected: _repeat == repeat,
                  onSelected: (_) => setState(() => _repeat = repeat),
                ),
            ],
          ),
          if (_repeat != ReminderRepeat.none) ...[
            const SizedBox(height: 16),
            Text(
              'How many times',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTextColors.secondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _repeatCount > 1
                      ? () => setState(() => _repeatCount--)
                      : null,
                  icon: const Icon(CupertinoIcons.minus),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_repeatCount ${_repeatCount == 1 ? 'time' : 'times'}',
                      style: TextStyle(
                          fontSize: 16, color: AppTextColors.primary(context)),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _repeatCount < 99
                      ? () => setState(() => _repeatCount++)
                      : null,
                  icon: const Icon(CupertinoIcons.add),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              if (_existing != null)
                Expanded(
                  child: TextButton(
                    onPressed: _remove,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.destructive),
                    child: const Text('Remove Reminder'),
                  ),
                ),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.accent),
                  child: Text(
                      _existing == null ? 'Set Reminder' : 'Update Reminder'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
