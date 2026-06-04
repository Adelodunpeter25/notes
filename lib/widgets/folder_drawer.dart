import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../database/daos.dart';
import '../utils/dialogs.dart';
import '../theme.dart';

/// A full-screen drawer for mobile showing folders, 'All Notes', and 'Trash'.
class FolderDrawer extends StatelessWidget {
  final List<FolderWithCount> folders;
  final int selectedIndex;
  final ValueChanged<int> onFolderSelected;
  final String userId;

  const FolderDrawer({
    super.key,
    required this.folders,
    required this.selectedIndex,
    required this.onFolderSelected,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);

    return Drawer(
      backgroundColor: AppSurfaces.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.folder_fill,
                    color: AppColors.accent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Folders',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: AppSurfaces.divider(context),
              indent: 20,
              endIndent: 20,
            ),
            const SizedBox(height: 8),

            // All Notes
            _FolderTile(
              icon: CupertinoIcons.doc_text_fill,
              iconColor: AppColors.accent,
              label: 'All Notes',
              isSelected: selectedIndex == 0,
              onTap: () => onFolderSelected(0),
            ),

            // Folder list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final fc = folders[index];
                  final folderIndex = index + 1;
                  return _FolderTile(
                    icon: CupertinoIcons.folder_fill,
                    iconColor: AppColors.accent,
                    label: fc.folder.name,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppSurfaces.divider(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        fc.noteCount.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTextColors.secondary(context),
                        ),
                      ),
                    ),
                    isSelected: selectedIndex == folderIndex,
                    onTap: () => onFolderSelected(folderIndex),
                    onLongPress: () async {
                      _showFolderActions(context, fc, services);
                    },
                  );
                },
              ),
            ),

            // Trash
            _FolderTile(
              icon: CupertinoIcons.trash_fill,
              iconColor: AppColors.destructive,
              label: 'Trash',
              isSelected: selectedIndex == folders.length + 1,
              onTap: () => onFolderSelected(folders.length + 1),
            ),

            Divider(
              height: 1,
              color: AppSurfaces.divider(context),
              indent: 20,
              endIndent: 20,
            ),

            // New Folder Button
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextButton.icon(
                onPressed: () async {
                  final folderName = await DialogUtils.showTextInputDialog(
                    context: context,
                    title: 'New Folder',
                    placeholder: 'Enter folder name',
                    primaryButtonText: 'Create',
                  );
                  if (folderName != null && folderName.trim().isNotEmpty) {
                    await services.folderService.createFolder(
                      folderName.trim(),
                      userId,
                    );
                  }
                },
                icon: const Icon(CupertinoIcons.add_circled_solid, color: AppColors.accent),
                label: const Text(
                  'New Folder',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderActions(BuildContext context, FolderWithCount fc, ServiceProvider services) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.pencil),
              title: const Text('Rename Folder'),
              onTap: () async {
                Navigator.pop(context);
                final newName = await DialogUtils.showTextInputDialog(
                  context: context,
                  title: 'Rename Folder',
                  placeholder: fc.folder.name,
                  primaryButtonText: 'Rename',
                );
                if (newName != null && newName.trim().isNotEmpty) {
                  await services.folderService.renameFolder(fc.folder, newName.trim());
                }
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: AppColors.destructive),
              title: const Text('Delete Folder', style: TextStyle(color: AppColors.destructive)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await DialogUtils.showConfirmation(
                  context: context,
                  title: 'Delete Folder?',
                  message: 'Are you sure you want to delete this folder and all its contents?',
                  primaryButtonText: 'Delete',
                  isDestructive: true,
                );
                if (confirmed) {
                  await services.folderService.softDeleteFolder(fc.folder);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FolderTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? AppSurfaces.elevated(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
