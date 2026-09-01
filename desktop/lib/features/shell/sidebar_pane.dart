import 'package:flutter/material.dart';

import '../../app/service_scope.dart';
import '../../app/theme.dart';
import '../../data/database/daos.dart';
import 'sidebar_helpers.dart';

/// Sidebar view modes.
enum SidebarView { all, trash, folder }

class SidebarSelection {
  final SidebarView view;
  final String? folderId;

  const SidebarSelection.all()
      : view = SidebarView.all,
        folderId = null;
  const SidebarSelection.trash()
      : view = SidebarView.trash,
        folderId = null;
  const SidebarSelection.folder(this.folderId) : view = SidebarView.folder;
}

/// Left pane: All Notes / folders / Trash with live note counts.
///
/// Caches its streams so parent rebuilds (e.g. selecting a note) don't
/// resubscribe and cause flicker/rerender of the whole list.
class SidebarPane extends StatefulWidget {
  final String userId;
  final SidebarSelection selection;
  final ValueChanged<SidebarSelection> onSelectionChanged;
  final VoidCallback onNewFolder;
  final VoidCallback onLogout;

  const SidebarPane({
    super.key,
    required this.userId,
    required this.selection,
    required this.onSelectionChanged,
    required this.onNewFolder,
    required this.onLogout,
  });

  @override
  State<SidebarPane> createState() => _SidebarPaneState();
}

class _SidebarPaneState extends State<SidebarPane> {
  late Stream<List<FolderWithCount>> _foldersStream;
  late Stream<int> _allCountStream;
  late Stream<int> _trashCountStream;
  ServiceScope? _scope;
  String? _boundUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ServiceScope.of(context);
    // Recreate streams only when the user changes or scope changes.
    if (_boundUserId != widget.userId || _scope != scope) {
      _scope = scope;
      _boundUserId = widget.userId;
      _foldersStream = scope.folderService.watchFolders(widget.userId);
      // Cache count streams separately so we don't rebuild them on every
      // ShellPage setState (e.g. note selection change).
      _allCountStream = scope.noteService.watchAllNotesCount(widget.userId);
      _trashCountStream = scope.noteService.watchTrashNotesCount(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope ?? ServiceScope.of(context);

    return Container(
      color: AppSurfaces.surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Note',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTextColors.primary(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  tooltip: 'New Folder',
                  onPressed: widget.onNewFolder,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<FolderWithCount>>(
              stream: _foldersStream,
              builder: (context, snapshot) {
                final folders = snapshot.data ?? const <FolderWithCount>[];
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // All Notes with live count
                    StreamBuilder<int>(
                      stream: _allCountStream,
                      builder: (context, countSnap) => SidebarItem(
                        icon: Icons.notes_outlined,
                        label: 'All Notes',
                        count: countSnap.data,
                        selected:
                            widget.selection.view == SidebarView.all,
                        onTap: () => widget.onSelectionChanged(
                            const SidebarSelection.all()),
                      ),
                    ),
                    ...folders.map((f) => SidebarItem(
                          icon: Icons.folder_outlined,
                          label: f.folder.name,
                          count: f.noteCount,
                          selected: widget.selection.view ==
                                  SidebarView.folder &&
                              widget.selection.folderId == f.folder.id,
                          onTap: () => widget.onSelectionChanged(
                              SidebarSelection.folder(f.folder.id)),
                          onSecondaryTapUp: (details) =>
                              _showFolderMenu(context, scope, f, details),
                        )),
                    // Trash with live count
                    StreamBuilder<int>(
                      stream: _trashCountStream,
                      builder: (context, countSnap) => SidebarItem(
                        icon: Icons.delete_outline,
                        label: 'Trash',
                        count:
                            (countSnap.data != null && countSnap.data! > 0)
                                ? countSnap.data
                                : null,
                        selected:
                            widget.selection.view == SidebarView.trash,
                        onTap: () => widget.onSelectionChanged(
                            const SidebarSelection.trash()),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: TextButton.icon(
              onPressed: widget.onLogout,
              icon: Icon(Icons.logout,
                  size: 16, color: AppTextColors.secondary(context)),
              label: Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTextColors.secondary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFolderMenu(BuildContext context, ServiceScope scope,
      FolderWithCount folder, TapUpDetails details) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx + 1,
        details.globalPosition.dy + 1,
      ),
      items: const [
        PopupMenuItem(value: 'rename', child: Text('Rename Folder')),
        PopupMenuItem(value: 'delete', child: Text('Delete Folder')),
      ],
    );
    if (action == null || !context.mounted) return;

    if (action == 'rename') {
      final name =
          await promptText(context, 'Rename Folder', folder.folder.name);
      if (name != null && name.isNotEmpty) {
        await scope.folderService.renameFolder(folder.folder, name);
      }
    } else if (action == 'delete') {
      final confirmed = await confirmDialog(
        context,
        title: 'Delete Folder?',
        message:
            'Notes inside "${folder.folder.name}" will be moved back to All Notes.',
      );
      if (confirmed == true) {
        await scope.folderService.deleteFolder(folder.folder);
        if (widget.selection.folderId == folder.folder.id) {
          widget.onSelectionChanged(const SidebarSelection.all());
        }
      }
    }
  }
}
