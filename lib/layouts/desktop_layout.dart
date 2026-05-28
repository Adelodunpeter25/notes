import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../widgets/sidebar.dart';
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
        onPageChanged: (index) => setState(() => _pageIndex = index),
      ),
      child: IndexedStack(
        index: _pageIndex,
        children: const [
          NotesViewPane(), // Main notes view with list + editor
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
    return const MacosScaffold(
      children: [
        ContentArea(
          builder: (context, scrollController) {
            return Row(
              children: [
                SizedBox(
                  width: 300,
                  child: NoteListPane(),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
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
