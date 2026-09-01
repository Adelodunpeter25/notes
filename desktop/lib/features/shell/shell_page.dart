import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/service_scope.dart';
import '../../app/theme.dart';
import '../../data/database/daos.dart';
import '../../data/database/database.dart' hide User;
import '../auth/auth_page.dart';
import '../editor/editor_pane.dart';
import 'note_list_pane.dart';
import 'sidebar_helpers.dart';
import 'sidebar_pane.dart';
import 'title_bar.dart';

/// Main three-pane layout: sidebar / note list / editor.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> with WindowListener {
  String? _userId;
  SidebarSelection _selection = const SidebarSelection.all();
  String _searchQuery = '';
  Note? _selectedNote;
  bool _isSyncing = false;
  bool _bootstrapped = false;

  // Pane persistence
  double _sidebarWidth = 220;
  double _listWidth = 320;
  static const double _minSidebar = 160;
  static const double _maxSidebar = 360;
  static const double _minList = 260;
  static const double _maxList = 480;
  static const String _kSidebarWidth = 'pane_sidebar_width';
  static const String _kListWidth = 'pane_list_width';

  // Folder name cache for view title
  Map<String, String> _folderNames = {};
  StreamSubscription<List<FolderWithCount>>? _folderSub;

  // Editor state lifted for title-bar toolbar
  EditorState? _currentEditorState;

  @override
  void initState() {
    super.initState();
    try {
      windowManager.addListener(this);
    } catch (_) {}
    _loadPaneWidths();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _bootstrap();
  }

  Future<void> _loadPaneWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sw = prefs.getDouble(_kSidebarWidth);
      final lw = prefs.getDouble(_kListWidth);
      if (!mounted) return;
      setState(() {
        if (sw != null) _sidebarWidth = sw.clamp(_minSidebar, _maxSidebar);
        if (lw != null) _listWidth = lw.clamp(_minList, _maxList);
      });
    } catch (_) {}
  }

  Future<void> _savePaneWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kSidebarWidth, _sidebarWidth);
      await prefs.setDouble(_kListWidth, _listWidth);
    } catch (_) {}
  }

  Future<void> _bootstrap() async {
    final scope = ServiceScope.of(context);
    final user = await scope.authService.getCurrentUser();
    if (!mounted) return;
    if (user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
      return;
    }
    setState(() => _userId = user.id);
    _listenFolderNames();
    // Restore window bounds after user is known (so we have a stable context).
    _restoreWindowBounds();
    _sync();
  }

  void _listenFolderNames() {
    if (_userId == null) return;
    _folderSub?.cancel();
    // Capture scope synchronously before the stream subscription.
    final scope = ServiceScope.of(context);
    _folderSub = scope.folderService.watchFolders(_userId!).listen((folders) {
      if (!mounted) return;
      final map = {for (final f in folders) f.folder.id: f.folder.name};
      // Only rebuild if names actually changed to reduce flicker.
      if (map.length != _folderNames.length ||
          map.entries.any((e) => _folderNames[e.key] != e.value)) {
        setState(() => _folderNames = map);
      }
    });
  }

  Future<void> _restoreWindowBounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final w = prefs.getDouble('window_width');
      final h = prefs.getDouble('window_height');
      if (w != null && h != null) {
        await windowManager.setSize(Size(w, h));
      }
      final x = prefs.getDouble('window_x');
      final y = prefs.getDouble('window_y');
      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
    } catch (_) {}
  }

  Future<void> _persistWindowBounds() async {
    try {
      final bounds = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('window_width', bounds.size.width);
      await prefs.setDouble('window_height', bounds.size.height);
      await prefs.setDouble('window_x', bounds.topLeft.dx);
      await prefs.setDouble('window_y', bounds.topLeft.dy);
    } catch (_) {}
  }

  @override
  void onWindowResized() => _persistWindowBounds();

  @override
  void onWindowMoved() => _persistWindowBounds();

  @override
  void dispose() {
    try {
      windowManager.removeListener(this);
    } catch (_) {}
    _folderSub?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_userId == null || _isSyncing) return;
    final scope = ServiceScope.of(context);
    setState(() => _isSyncing = true);
    try {
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
    if (!mounted) return;
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
      _folderNames[folder.id] = folder.name;
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
        final id = _selection.folderId;
        if (id != null && _folderNames.containsKey(id)) {
          return _folderNames[id]!;
        }
        return 'Folder';
    }
  }

  void _onSidebarWidthChanged(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(_minSidebar, _maxSidebar);
    });
  }

  void _onListWidthChanged(double delta) {
    setState(() {
      _listWidth = (_listWidth + delta).clamp(_minList, _maxList);
    });
  }

  void _onPaneDragEnd() => _savePaneWidths();

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppSurfaces.background(context),
      body: Column(
        children: [
          // Apple Notes–style title bar with centered toolbar
          ShellTitleBar(
            editorState: _currentEditorState,
            viewTitle: _viewTitle,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _sidebarWidth,
                  child: SidebarPane(
                    userId: _userId!,
                    selection: _selection,
                    onSelectionChanged: (selection) => setState(() {
                      _selection = selection;
                      _searchQuery = '';
                      _selectedNote = null;
                      _currentEditorState = null;
                    }),
                    onNewFolder: _createFolder,
                    onLogout: _logout,
                  ),
                ),
                _PaneDivider(
                  onDelta: _onSidebarWidthChanged,
                  onEnd: _onPaneDragEnd,
                ),
                SizedBox(
                  width: _listWidth,
                  child: NoteListPane(
                    userId: _userId!,
                    viewTitle: _viewTitle,
                    isTrash: _selection.view == SidebarView.trash,
                    folderId: _selection.view == SidebarView.folder
                        ? _selection.folderId
                        : null,
                    searchQuery: _searchQuery,
                    selectedNote: _selectedNote,
                    onSearchChanged: (query) =>
                        setState(() => _searchQuery = query),
                    onNoteSelected: (note) =>
                        setState(() => _selectedNote = note),
                    onNewNote: _createNote,
                    onSync: _sync,
                    isSyncing: _isSyncing,
                  ),
                ),
                _PaneDivider(
                  onDelta: _onListWidthChanged,
                  onEnd: _onPaneDragEnd,
                ),
                Expanded(
                  child: EditorPane(
                    note: _selectedNote,
                    onNoteSaved: (updated) =>
                        setState(() => _selectedNote = updated),
                    onEditorStateChanged: (es) =>
                        setState(() => _currentEditorState = es),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin draggable divider between panes, saves width on drag end.
class _PaneDivider extends StatefulWidget {
  final ValueChanged<double> onDelta;
  final VoidCallback onEnd;

  const _PaneDivider({required this.onDelta, required this.onEnd});

  @override
  State<_PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<_PaneDivider> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => widget.onDelta(details.delta.dx),
        onHorizontalDragEnd: (_) => widget.onEnd(),
        child: Container(
          width: 7,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: _hovering
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : AppSurfaces.divider(context),
            ),
          ),
        ),
      ),
    );
  }
}
