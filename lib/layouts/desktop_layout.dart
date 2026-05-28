import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showMenu, RelativeRect, PopupMenuItem, PopupMenuEntry;
import 'package:macos_ui/macos_ui.dart';
import '../widgets/note_list.dart';
import '../widgets/editor_view.dart';
import '../widgets/service_provider.dart';
import '../utils/dialogs.dart';
import '../models/user.dart';
import '../database/daos.dart';

class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  int _pageIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);

    return FutureBuilder<User?>(
      future: services.authService.getCurrentUser(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressCircle());
        }
        
        final user = userSnapshot.data;
        if (user == null) {
          return const Center(child: Text('Not logged in'));
        }

        return StreamBuilder<List<FolderWithCount>>(
          stream: services.folderService.watchFolders(user.id),
          builder: (context, folderSnapshot) {
            final folders = folderSnapshot.data ?? [];

            // Construct sidebar items dynamically
            final List<SidebarItem> sidebarItems = [
              const SidebarItem(
                leading: MacosIcon(CupertinoIcons.folder, color: CupertinoColors.systemYellow),
                label: Text('All Notes'),
              ),
            ];

            for (final fc in folders) {
              sidebarItems.add(
                SidebarItem(
                  leading: const MacosIcon(CupertinoIcons.folder, color: CupertinoColors.systemYellow),
                  label: Builder(
                    builder: (context) {
                      return GestureDetector(
                        onSecondaryTapUp: (details) async {
                          final RelativeRect position = RelativeRect.fromLTRB(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          );

                          final result = await showMenu<String>(
                            context: context,
                            position: position,
                            color: MacosTheme.of(context).canvasColor,
                            elevation: 8,
                            items: <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'rename',
                                height: 32,
                                child: Text('Rename Folder', style: TextStyle(fontSize: 13)),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                height: 32,
                                child: Text(
                                  'Delete',
                                  style: TextStyle(fontSize: 13, color: CupertinoColors.destructiveRed),
                                ),
                              ),
                            ],
                          );

                          if (result == 'delete' && context.mounted) {
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
                          } else if (result == 'rename' && context.mounted) {
                            final newName = await DialogUtils.showTextInputDialog(
                              context: context,
                              title: 'Rename Folder',
                              placeholder: 'Enter new folder name',
                            );
                            if (newName != null && newName.trim().isNotEmpty) {
                              await services.folderService.renameFolder(fc.folder, newName.trim());
                            }
                          }
                        },
                        child: Text(fc.folder.name),
                      );
                    },
                  ),
                  trailing: Text(fc.noteCount.toString(), style: const TextStyle(color: CupertinoColors.systemGrey)),
                ),
              );
            }

            sidebarItems.add(
              const SidebarItem(
                leading: MacosIcon(CupertinoIcons.trash, color: CupertinoColors.systemYellow),
                label: Text('Trash'),
              ),
            );

            // Determine body child based on _pageIndex
            final Widget bodyChild;
            if (_pageIndex == 0) {
              bodyChild = const NotesViewPane(filter: NoteFilter.all());
            } else if (_pageIndex == folders.length + 1) {
              bodyChild = const NotesViewPane(filter: NoteFilter.trash());
            } else {
              if (_pageIndex - 1 < folders.length) {
                final folder = folders[_pageIndex - 1].folder;
                bodyChild = NotesViewPane(filter: NoteFilter.folder(folder.id));
              } else {
                bodyChild = const NotesViewPane(filter: NoteFilter.all());
              }
            }

            return MacosWindow(
              sidebar: Sidebar(
                minWidth: 220,
                builder: (context, scrollController) {
                  return SidebarItems(
                    currentIndex: _pageIndex,
                    onChanged: (index) => setState(() => _pageIndex = index),
                    scrollController: scrollController,
                    items: sidebarItems,
                  );
                },
                bottom: Column(
                  children: [
                    Container(height: 1, color: MacosTheme.of(context).dividerColor),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () async {
                            final folderName = await DialogUtils.showTextInputDialog(
                              context: context,
                              title: 'New Folder',
                              placeholder: 'Enter folder name',
                            );
                            if (folderName != null && folderName.trim().isNotEmpty) {
                              await services.folderService.createFolder(
                                folderName.trim(),
                                user.id,
                              );
                            }
                          },
                          child: const Row(
                            children: [
                              MacosIcon(CupertinoIcons.add_circled, size: 20),
                              SizedBox(width: 8),
                              Text('New Folder', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              child: bodyChild,
            );
          },
        );
      },
    );
  }
}

class NotesViewPane extends StatelessWidget {
  final NoteFilter filter;

  const NotesViewPane({super.key, required this.filter});

  @override
  Widget build(BuildContext context) {
    return MacosScaffold(
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Row(
              children: [
                SizedBox(
                  width: 300,
                  child: NoteListPane(filter: filter),
                ),
                Container(width: 1, color: MacosTheme.of(context).dividerColor),
                const Expanded(
                  child: EditorViewPane(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
