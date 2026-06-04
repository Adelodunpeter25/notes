import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../widgets/note_list.dart';
import '../widgets/editor_view.dart';
import '../widgets/folders_view.dart';

import '../models/user.dart';
import '../database/daos.dart';
import '../database/database.dart' hide User;

enum ScreenType { folders, notes, editor }

class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  ScreenType _currentScreen = ScreenType.folders;
  int _selectedFolderIndex = 0; // 0 = All Notes
  Note? _selectedNote;
  
  User? _currentUser;
  Stream<List<FolderWithCount>>? _foldersStream;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_currentUser != null) return;
    final services = ServiceProvider.of(context);
    final user = await services.authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
        if (user != null) {
          _foldersStream = services.folderService.watchFolders(user.id);
        }
      });
      _performSync();
    }
  }

  Future<void> _performSync() async {
    if (!mounted || _currentUser == null) return;
    final services = ServiceProvider.of(context);
    await services.syncService.syncData(_currentUser!.id);
  }

  void _onNoteSelected(Note note) {
    setState(() {
      _selectedNote = note;
      _currentScreen = ScreenType.editor;
    });
  }

  void _onBackFromEditor() {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentScreen = ScreenType.notes;
    });
  }

  void _onFolderSelected(int index) {
    setState(() {
      _selectedFolderIndex = index;
      _currentScreen = ScreenType.notes;
    });
  }

  void _onBackFromNotes() {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentScreen = ScreenType.folders;
      _selectedNote = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final services = ServiceProvider.of(context);

    return StreamBuilder<List<FolderWithCount>>(
      stream: _foldersStream,
      builder: (context, folderSnapshot) {
        final folders = folderSnapshot.data ?? [];

        // Determine filter
        final NoteFilter filter;
        if (_selectedFolderIndex == 0) {
          filter = const NoteFilter.all();
        } else if (_selectedFolderIndex == folders.length + 1) {
          filter = const NoteFilter.trash();
        } else if (_selectedFolderIndex - 1 < folders.length) {
          filter = NoteFilter.folder(folders[_selectedFolderIndex - 1].folder.id);
        } else {
          filter = const NoteFilter.all();
        }

        // Get current folder name for app bar
        String currentFolderName;
        if (_selectedFolderIndex == 0) {
          currentFolderName = 'All Notes';
        } else if (_selectedFolderIndex == folders.length + 1) {
          currentFolderName = 'Trash';
        } else if (_selectedFolderIndex - 1 < folders.length) {
          currentFolderName = folders[_selectedFolderIndex - 1].folder.name;
        } else {
          currentFolderName = 'All Notes';
        }

        Widget screen;
        switch (_currentScreen) {
          case ScreenType.folders:
            screen = FoldersView(
              key: const ValueKey('folders_screen'),
              folders: folders,
              onFolderSelected: _onFolderSelected,
              userId: _currentUser!.id,
            );
            break;
          case ScreenType.notes:
            screen = NoteList(
              key: ValueKey('list_${filter.type}_${filter.folderId}'),
              filter: filter,
              folderName: currentFolderName,
              onNoteSelected: _onNoteSelected,
              onMenuPressed: _onBackFromNotes,
              onNewNote: () async {
                String? folderId;
                if (_selectedFolderIndex > 0 && _selectedFolderIndex <= folders.length) {
                  folderId = folders[_selectedFolderIndex - 1].folder.id;
                }
                final newNote = await services.noteService.createNote(
                  title: '',
                  content: '',
                  userId: _currentUser!.id,
                  folderId: folderId,
                );
                _onNoteSelected(newNote);
              },
              onSync: _performSync,
            );
            break;
          case ScreenType.editor:
            screen = EditorView(
              key: ValueKey('editor_${_selectedNote!.id}'),
              note: _selectedNote!,
              onBack: _onBackFromEditor,
              onNoteUpdated: (updatedNote) {
                setState(() {
                  _selectedNote = updatedNote;
                });
              },
            );
            break;
        }

        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              if (child.key == const ValueKey('folders_screen')) {
                return FadeTransition(opacity: animation, child: child);
              }
              // Slide transition for NoteList and Editor
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              );
            },
            child: screen,
          ),
        );
      },
    );
  }
}
