import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showMenu, RelativeRect, PopupMenuItem, PopupMenuEntry;
import 'package:macos_ui/macos_ui.dart';
import '../widgets/note_list.dart';
import '../widgets/editor_view.dart';
import '../utils/dialogs.dart';

class DesktopLayout extends StatefulWidget {
  const DesktopLayout({super.key});

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MacosWindow(
      sidebar: Sidebar(
        minWidth: 220,
        builder: (context, scrollController) {
          return SidebarItems(
            currentIndex: _pageIndex,
            onChanged: (index) => setState(() => _pageIndex = index),
            scrollController: scrollController,
            items: [
              const SidebarItem(
                leading: MacosIcon(CupertinoIcons.folder, color: CupertinoColors.systemYellow),
                label: Text('All Notes'),
                trailing: Text('35', style: TextStyle(color: CupertinoColors.systemGrey)),
              ),
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
                            // Soft delete logic
                          }
                        }
                      },
                      child: const Text('Personal'),
                    );
                  },
                ),
                trailing: const Text('8', style: TextStyle(color: CupertinoColors.systemGrey)),
              ),
              const SidebarItem(
                leading: MacosIcon(CupertinoIcons.trash, color: CupertinoColors.systemYellow),
                label: Text('Trash'),
                trailing: Text('1', style: TextStyle(color: CupertinoColors.systemGrey)),
              ),
            ],
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
                  onTap: () {
                    // Logic to create new folder
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
      child: IndexedStack(
        index: _pageIndex,
        children: const [
          NotesViewPane(),
          Center(child: Text('Shared')),
          Center(child: Text('Trash')),
        ],
      ),
    );
  }
}

class NotesViewPane extends StatelessWidget {
  const NotesViewPane({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosScaffold(
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Row(
              children: [
                const SizedBox(
                  width: 300,
                  child: NoteListPane(),
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
