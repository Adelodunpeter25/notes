import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

class EditorViewPane extends StatefulWidget {
  const EditorViewPane({super.key});

  @override
  State<EditorViewPane> createState() => _EditorViewPaneState();
}

class _EditorViewPaneState extends State<EditorViewPane> {
  late EditorState _editorState;

  @override
  void initState() {
    super.initState();
    _editorState = EditorState.blank();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // macOS Toolbar
        const EditorToolbar(),
        const Divider(height: 1),
        // The actual editor
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: AppFlowyEditor(
              editorState: _editorState,
            ),
          ),
        ),
      ],
    );
  }
}

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.share),
            onPressed: () {},
          ),
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.trash),
            onPressed: () {},
          ),
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.square_and_pencil),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
