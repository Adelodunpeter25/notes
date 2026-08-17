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
        icon: 'ic_new_note',
      ),
      const ShortcutItem(
        type: 'new_folder',
        localizedTitle: 'New Folder',
        icon: 'ic_new_folder',
      ),
    ];

    await _quickActions.setShortcutItems(items);
  }
}
