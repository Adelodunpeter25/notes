import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../widgets/search_bar.dart';
import '../database/daos.dart';
import '../utils/dialogs.dart';
import '../theme.dart';

class FoldersView extends StatefulWidget {
  final List<FolderWithCount> folders;
  final ValueChanged<int> onFolderSelected;
  final String userId;
  final VoidCallback onNewNote;

  const FoldersView({
    super.key,
    required this.folders,
    required this.onFolderSelected,
    required this.userId,
    required this.onNewNote,
  });

  @override
  State<FoldersView> createState() => _FoldersViewState();
}

class _FoldersViewState extends State<FoldersView> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<int> _countAllNotes(ServiceProvider services, String userId) async {
    final list = await services.db
        .select(services.db.notes)
        .get();
    return list.where((n) => n.userId == userId && n.deletedAt == null).length;
  }

  Future<int> _countTrashNotes(ServiceProvider services, String userId) async {
    final list = await services.db
        .select(services.db.notes)
        .get();
    return list.where((n) => n.userId == userId && n.deletedAt != null).length;
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);

    // Filter custom folders
    final filteredFolders = widget.folders.where((fc) {
      if (_searchQuery.isEmpty) return true;
      return fc.folder.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppSurfaces.background(context),
      appBar: AppBar(
        backgroundColor: AppSurfaces.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Folders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppTextColors.primary(context),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Search Bar at the top of the list
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: CustomSearchBar(
                      controller: _searchController,
                      placeholder: 'Search folders',
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                    ),
                  ),

                  // Only show All Notes and Trash if query is empty or matches their titles
                  if (_searchQuery.isEmpty || 'all notes'.contains(_searchQuery.toLowerCase())) ...[
                    FutureBuilder<int>(
                      future: _countAllNotes(services, widget.userId),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return _FolderCard(
                          icon: CupertinoIcons.doc_text_fill,
                          iconColor: AppColors.accent,
                          title: 'All Notes',
                          count: count,
                          onTap: () => widget.onFolderSelected(0),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Header for Custom Folders
                  if (filteredFolders.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text(
                        'MY FOLDERS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTextColors.tertiary(context),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],

                  // Custom folders (with unified CupertinoIcons.folder)
                  ...List.generate(filteredFolders.length, (index) {
                    final fc = filteredFolders[index];
                    final originalIndex = widget.folders.indexOf(fc);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _FolderCard(
                        icon: CupertinoIcons.folder, // Central folder icon for all custom folders
                        iconColor: AppColors.accent,
                        title: fc.folder.name,
                        count: fc.noteCount,
                        onTap: () => widget.onFolderSelected(originalIndex + 1),
                        onLongPress: () => _showFolderActions(context, fc, services),
                      ),
                    );
                  }),

                  if (_searchQuery.isEmpty || 'trash'.contains(_searchQuery.toLowerCase())) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<int>(
                      future: _countTrashNotes(services, widget.userId),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return _FolderCard(
                          icon: CupertinoIcons.trash_fill,
                          iconColor: AppColors.destructive,
                          title: 'Trash',
                          count: count,
                          onTap: () => widget.onFolderSelected(widget.folders.length + 1),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Floating dark card dock bottom bar with reduced height
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
              child: Container(
                height: 54, // Reduced height
                decoration: BoxDecoration(
                  color: Colors.grey[900], // Dark distinct surface color for dock
                  borderRadius: BorderRadius.circular(27), // Capsule pill
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: IconButton(
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
                              widget.userId,
                            );
                          }
                        },
                        icon: const Icon(
                          CupertinoIcons.folder_badge_plus,
                          color: AppColors.accent,
                          size: 24, // Sized perfectly for reduced height
                        ),
                        tooltip: 'New Folder',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        onPressed: widget.onNewNote,
                        icon: const Icon(
                          CupertinoIcons.square_pencil,
                          color: AppColors.accent,
                          size: 24, // Sized perfectly for reduced height
                        ),
                        tooltip: 'New Note',
                      ),
                    ),
                  ],
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

class _FolderCard extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FolderCard({
    this.icon,
    this.iconColor,
    required this.title,
    required this.count,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppSurfaces.surface(context),
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTextColors.primary(context),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTextColors.secondary(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: AppTextColors.quaternary(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
