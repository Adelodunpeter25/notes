import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

class Sidebar extends StatelessWidget {
  final Function(int) onPageChanged;

  const Sidebar({super.key, required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    return Sidebar(
      minWidth: 200,
      builder: (context, scrollController) {
        return SidebarItems(
          currentIndex: 0,
          onChanged: onPageChanged,
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
      bottom: const Column(
        children: [
          Divider(),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                MacosIcon(CupertinoIcons.add),
                SizedBox(width: 8),
                Text('New Folder'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
