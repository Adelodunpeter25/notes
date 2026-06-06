import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../widgets/search_bar.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/sync_button.dart';
import '../database/daos.dart';
import '../utils/dialogs.dart';
import '../theme.dart';

class FoldersView extends StatefulWidget {
  final List<FolderWithCount> folders;
  final ValueChanged<int> onFolderSelected;
  final String userId;
  final VoidCallback onNewNote;
  final Future<void> Function() onSync;

  const FoldersView({
    super.key,
    required this.folders,
    required this.onFolderSelected,
    required this.userId,
    required this.onNewNote,
    required this.onSync,
  });

  @override
  State<FoldersView> createState() => _FoldersViewState();
}

class _FoldersViewState extends State<FoldersView> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  Stream<int>? _allCountStream;
  Stream<int>? _trashCountStream;
  Stream<Map<String, int>>? _perFolderStream;
  String? _cachedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = widget.userId;
    if (_cachedUserId != userId) {
      _cachedUserId = userId;
      final services = ServiceProvider.of(context);
      _allCountStream = services.noteService.watchAllNotesCount(userId);
      _trashCountStream = services.noteService.watchTrashNotesCount(userId);
      _perFolderStream = services.noteService.watchPerFolderCounts(userId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);

    final filteredFolders = widget.folders.where((fc) {
      if (_searchQuery.isEmpty) return true;
      return fc.folder.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final allCountStream = _allCountStream!;
    final trashCountStream = _trashCountStream!;
    final perFolderStream = _perFolderStream!;

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
        actions: [
          RotatingSyncButton(onSync: widget.onSync),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<int>(
          stream: allCountStream,
          initialData: 0,
          builder: (context, allSnap) {
            return StreamBuilder<int>(
              stream: trashCountStream,
              initialData: 0,
              builder: (context, trashSnap) {
                return StreamBuilder<Map<String, int>>(
                  stream: perFolderStream,
                  initialData: const {},
                  builder: (context, perFolderSnap) {
                    final allCount = allSnap.data ?? 0;
                    final trashCount = trashSnap.data ?? 0;
                    final perFolder = perFolderSnap.data ?? const <String, int>{};

                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            children: [
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

                              if (_searchQuery.isEmpty || 'all notes'.contains(_searchQuery.toLowerCase())) ...[
                                _FolderCard(
                                  icon: CupertinoIcons.folder,
                                  iconColor: AppColors.accent,
                                  title: 'All Notes',
                                  count: allCount,
                                  onTap: () => widget.onFolderSelected(0),
                                ),
                                const SizedBox(height: 16),
                              ],

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

                              ...List.generate(filteredFolders.length, (index) {
                                final fc = filteredFolders[index];
                                final originalIndex = widget.folders.indexOf(fc);
                                final liveCount = perFolder[fc.folder.id] ?? fc.noteCount;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _FolderCard(
                                    icon: CupertinoIcons.folder,
                                    iconColor: AppColors.accent,
                                    title: fc.folder.name,
                                    count: liveCount,
                                    onTap: () => widget.onFolderSelected(originalIndex + 1),
                                    onLongPress: () => _showFolderActions(context, fc, services),
                                  ),
                                );
                              }),

                              if (_searchQuery.isNotEmpty &&
                                  filteredFolders.isEmpty &&
                                  !'all notes'.contains(_searchQuery.toLowerCase()) &&
                                  !'trash'.contains(_searchQuery.toLowerCase())) ...[
                                const SizedBox(height: 48),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.search,
                                        size: 64,
                                        color: AppTextColors.quaternary(context),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No folders match "$_searchQuery"',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: AppTextColors.tertiary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (_searchQuery.isEmpty || 'trash'.contains(_searchQuery.toLowerCase())) ...[
                                const SizedBox(height: 16),
                                _FolderCard(
                                  icon: CupertinoIcons.trash,
                                  iconColor: AppColors.destructive,
                                  title: 'Trash',
                                  count: trashCount,
                                  onTap: () => widget.onFolderSelected(widget.folders.length + 1),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppSurfaces.divider(context), width: 0.5),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
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
                                icon: const Icon(CupertinoIcons.folder_badge_plus, color: AppColors.accent, size: 26),
                              ),
                              IconButton(
                                onPressed: widget.onNewNote,
                                icon: const Icon(CupertinoIcons.square_pencil, color: AppColors.accent, size: 26),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showFolderActions(BuildContext context, FolderWithCount fc, ServiceProvider services) {
    AppBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                message: 'Are you sure you want to delete this folder? Notes inside will be moved back to All Notes.',
                primaryButtonText: 'Delete',
                isDestructive: true,
              );
              if (confirmed) {
                await services.folderService.deleteFolder(fc.folder);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
