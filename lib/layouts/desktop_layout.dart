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
        minWidth: 200,
        builder: (context, scrollController) {
          return SidebarItems(
            currentIndex: 0,
            onChanged: (index) => setState(() => _pageIndex = index),
            items: const [
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.folder),
                label: Text('All Notes'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.person_2),
                label: Text('Shared'),
              ),
              SidebarItem(
                leading: MacosIcon(CupertinoIcons.trash),
                label: Text('Trash'),
              ),
            ],
          );
        },
        bottom: Column(
          children: [
            Container(height: 1, color: MacosTheme.of(context).dividerColor),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: const [
                  MacosIcon(CupertinoIcons.add),
                  SizedBox(width: 8),
                  Text('New Folder'),
                ],
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
