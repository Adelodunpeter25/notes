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
class SidebarPane extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scope = ServiceScope.of(context);

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
                  onPressed: onNewFolder,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<FolderWithCount>>(
              stream: scope.folderService.watchFolders(userId),
              builder: (context, snapshot) {
                final folders = snapshot.data ?? const <FolderWithCount>[];
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    SidebarItem(
                      icon: Icons.notes_outlined,
                      label: 'All Notes',
                      selected: selection.view == SidebarView.all,
                      onTap: () =>
                          onSelectionChanged(const SidebarSelection.all()),
                    ),
                    ...folders.map((f) => SidebarItem(
                          icon: Icons.folder_outlined,
                          label: f.folder.name,
                          count: f.noteCount,
                          selected: selection.view == SidebarView.folder &&
                              selection.folderId == f.folder.id,
                          onTap: () => onSelectionChanged(
                              SidebarSelection.folder(f.folder.id)),
                          onSecondaryTapUp: (details) =>
                              _showFolderMenu(context, scope, f, details),
                        )),
                    SidebarItem(
                      icon: Icons.delete_outline,
                      label: 'Trash',
                      selected: selection.view == SidebarView.trash,
                      onTap: () =>
                          onSelectionChanged(const SidebarSelection.trash()),
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
              onPressed: onLogout,
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
        if (selection.folderId == folder.folder.id) {
          onSelectionChanged(const SidebarSelection.all());
        }
      }
    }
  }
}
