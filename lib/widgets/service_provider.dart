import 'package:flutter/widgets.dart';
import '../database/database.dart';
import '../services/auth.dart';
import '../services/folder_service.dart';
import '../services/note_service.dart';
import '../services/sync_service.dart';

class ServiceProvider extends InheritedWidget {
  final AppDatabase db;
  final AuthService authService;
  final FolderService folderService;
  final NoteService noteService;
  final SyncService syncService;

  const ServiceProvider({
    super.key,
    required this.db,
    required this.authService,
    required this.folderService,
    required this.noteService,
    required this.syncService,
    required super.child,
  });

  static ServiceProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<ServiceProvider>();
    assert(provider != null, 'No ServiceProvider found in context');
    return provider!;
  }

  @override
  bool updateShouldNotify(ServiceProvider oldWidget) {
    return db != oldWidget.db ||
        authService != oldWidget.authService ||
        folderService != oldWidget.folderService ||
        noteService != oldWidget.noteService ||
        syncService != oldWidget.syncService;
  }
}
