import 'dart:async';
import 'package:quick_actions/quick_actions.dart';

class QuickActionService {
  static final QuickActionService _instance = QuickActionService._internal();
  factory QuickActionService() => _instance;
  QuickActionService._internal();

  final QuickActions _quickActions = const QuickActions();
  final _actionController = StreamController<String>.broadcast();

  Stream<String> get onActionTriggered => _actionController.stream;

  void initialize() {
    _quickActions.initialize((String shortcutType) {
      _actionController.add(shortcutType);
    });
  }

  Future<void> updateShortcuts() async {
    final List<ShortcutItem> items = [
      const ShortcutItem(
        type: 'new_note',
        localizedTitle: 'New Note',
      ),
      const ShortcutItem(
        type: 'new_folder',
        localizedTitle: 'New Folder',
      ),
    ];

    await _quickActions.setShortcutItems(items);
  }
}
