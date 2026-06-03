import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../widgets/note_list.dart';
import '../widgets/editor_view.dart';
import '../widgets/folder_drawer.dart';

import '../models/user.dart';
import '../database/daos.dart';
import '../database/database.dart' hide User;

/// The mobile layout is a stack-based navigation:
/// 1. Note list (home) with a drawer for folders
/// 2. Editor view (pushed on top when a note is tapped)
class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  int _selectedFolderIndex = 0; // 0 = All Notes
  Note? _selectedNote;
  bool _showEditor = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSync();
    });
  }

  Future<void> _performSync() async {
    if (!mounted) return;
    final services = ServiceProvider.of(context);
    final user = await services.authService.getCurrentUser();
    if (user != null) {
      await services.syncService.syncData(user.id);
    }
  }

  void _onNoteSelected(Note note) {
    setState(() {
      _selectedNote = note;
      _showEditor = true;
    });
  }

  void _onBackFromEditor() {
    setState(() {
      _showEditor = false;
    });
  }

  void _onFolderSelected(int index) {
    setState(() {
      _selectedFolderIndex = index;
      _selectedNote = null;
      _showEditor = false;
    });
    Navigator.of(context).pop(); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);

    return FutureBuilder<User?>(
      future: services.authService.getCurrentUser(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CupertinoActivityIndicator()),
          );
        }

        final user = userSnapshot.data;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Not logged in')),
          );
        }

        return StreamBuilder<List<FolderWithCount>>(
          stream: services.folderService.watchFolders(user.id),
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

            return Scaffold(
              key: _scaffoldKey,
              drawer: FolderDrawer(
                folders: folders,
                selectedIndex: _selectedFolderIndex,
                onFolderSelected: _onFolderSelected,
                userId: user.id,
              ),
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  // Slide transition for editor
                  if (_showEditor) {
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
                  }
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _showEditor && _selectedNote != null
                    ? EditorView(
                        key: ValueKey('editor_${_selectedNote!.id}'),
                        note: _selectedNote!,
                        onBack: _onBackFromEditor,
                        onNoteUpdated: (updatedNote) {
                          setState(() {
                            _selectedNote = updatedNote;
                          });
                        },
                      )
                    : NoteList(
                        key: ValueKey('list_${filter.type}_${filter.folderId}'),
                        filter: filter,
                        folderName: currentFolderName,
                        onNoteSelected: _onNoteSelected,
                        onMenuPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        onNewNote: () async {
                          String? folderId;
                          if (_selectedFolderIndex > 0 && _selectedFolderIndex <= folders.length) {
                            folderId = folders[_selectedFolderIndex - 1].folder.id;
                          }
                          await services.noteService.createNote(
                            title: '',
                            content: '',
                            userId: user.id,
                            folderId: folderId,
                          );
                        },
                        onSync: () => _performSync(),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
