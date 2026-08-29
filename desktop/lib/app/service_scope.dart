import 'package:flutter/widgets.dart';
import '../data/database/database.dart';
import '../data/repositories/auth_service.dart';
import '../data/repositories/folder_service.dart';
import '../data/repositories/note_service.dart';
import '../data/sync/sync_service.dart';

/// Provides the core service graph to the widget tree.
/// (Desktop equivalent of the mobile app's ServiceProvider.)
class ServiceScope extends InheritedWidget {
  final AppDatabase db;
  final AuthService authService;
  final FolderService folderService;
  final NoteService noteService;
  final SyncService syncService;

  const ServiceScope({
    super.key,
    required this.db,
    required this.authService,
    required this.folderService,
    required this.noteService,
    required this.syncService,
    required super.child,
  });

  static ServiceScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ServiceScope>();
    assert(scope != null, 'No ServiceScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(ServiceScope oldWidget) {
    return db != oldWidget.db ||
        authService != oldWidget.authService ||
        folderService != oldWidget.folderService ||
        noteService != oldWidget.noteService ||
        syncService != oldWidget.syncService;
  }
}
