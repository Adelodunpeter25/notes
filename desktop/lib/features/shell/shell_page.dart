import 'package:flutter/material.dart';

import '../../app/service_scope.dart';
import '../../data/database/database.dart' hide User;
import '../auth/auth_page.dart';
import '../editor/editor_pane.dart';
import 'note_list_pane.dart';
import 'sidebar_helpers.dart';
import 'sidebar_pane.dart';

/// Main three-pane layout: sidebar / note list / editor.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  String? _userId;
  SidebarSelection _selection = const SidebarSelection.all();
  String _searchQuery = '';
  Note? _selectedNote;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final scope = ServiceScope.of(context);
    final user = await scope.authService.getCurrentUser();
    if (!mounted) return;
    if (user == null) {
      // No local user — bounce to auth.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
      return;
    }
    setState(() => _userId = user.id);
    _sync();
  }

  Future<void> _sync() async {
    if (_userId == null || _isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final scope = ServiceScope.of(context);
      await scope.syncService.syncData(_userId!);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _createNote() async {
    if (_userId == null) return;
    final scope = ServiceScope.of(context);
    final folderId =
        _selection.view == SidebarView.folder ? _selection.folderId : null;
    final note = await scope.noteService.createNote(
      title: '',
      content: '',
      userId: _userId!,
      folderId: folderId,
    );
    setState(() => _selectedNote = note);
  }

  Future<void> _createFolder() async {
    final name = await promptText(context, 'New Folder', '');
    if (name == null || name.isEmpty || _userId == null) return;
    if (!mounted) return;
    final scope = ServiceScope.of(context);
    final folder = await scope.folderService.createFolder(name, _userId!);
    if (!mounted) return;
    setState(() {
      _selection = SidebarSelection.folder(folder.id);
      _searchQuery = '';
    });
  }

  Future<void> _logout() async {
    final scope = ServiceScope.of(context);
    await scope.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  String get _viewTitle {
    switch (_selection.view) {
      case SidebarView.all:
        return 'All Notes';
      case SidebarView.trash:
        return 'Trash';
      case SidebarView.folder:
        return 'Folder';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 220,
            child: SidebarPane(
              userId: _userId!,
              selection: _selection,
              onSelectionChanged: (selection) => setState(() {
                _selection = selection;
                _searchQuery = '';
                _selectedNote = null;
              }),
              onNewFolder: _createFolder,
              onLogout: _logout,
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 320,
            child: NoteListPane(
              userId: _userId!,
              viewTitle: _viewTitle,
              isTrash: _selection.view == SidebarView.trash,
              searchQuery: _searchQuery,
              selectedNote: _selectedNote,
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              onNoteSelected: (note) => setState(() => _selectedNote = note),
              onNewNote: _createNote,
              onSync: _sync,
              isSyncing: _isSyncing,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: EditorPane(
              note: _selectedNote,
              onNoteSaved: (updated) =>
                  setState(() => _selectedNote = updated),
            ),
          ),
        ],
      ),
    );
  }
}
