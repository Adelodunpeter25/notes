import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../widgets/note_list.dart';
import '../widgets/editor_view.dart';

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
            items: const [
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.folder, color: CupertinoColors.systemYellow),
                label: Text('All Notes'),
                trailing: Text('35', style: TextStyle(color: CupertinoColors.systemGrey)),
              ),
              SidebarItem(
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
                  child: Row(
                    children: const [
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
          const Center(child: Text('Shared')),
          const Center(child: Text('Trash')),
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
