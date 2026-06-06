import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EditorSelectionMenu extends StatelessWidget {
  final EditorState editorState;
  final Offset anchor;
  final VoidCallback closeToolbar;

  const EditorSelectionMenu({
    super.key,
    required this.editorState,
    required this.anchor,
    required this.closeToolbar,
  });

  @override
  Widget build(BuildContext context) {
    final selection = editorState.selection;
    final isCollapsed = selection == null || selection.isCollapsed;

    return AdaptiveTextSelectionToolbar(
      anchors: TextSelectionToolbarAnchors(primaryAnchor: anchor),
      children: AdaptiveTextSelectionToolbar.getAdaptiveButtons(
        context,
        [
          if (!isCollapsed) ...[
            ContextMenuButtonItem(
              onPressed: () {
                copyCommand.execute(editorState);
                closeToolbar();
              },
              type: ContextMenuButtonType.copy,
            ),
            ContextMenuButtonItem(
              onPressed: () {
                cutCommand.execute(editorState);
                closeToolbar();
              },
              type: ContextMenuButtonType.cut,
            ),
            ContextMenuButtonItem(
              onPressed: () async {
                final text = editorState.getTextInSelection(selection).join('');
                if (text.isNotEmpty) {
                  final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(text)}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                }
                closeToolbar();
              },
              label: 'Lookup',
            ),
          ],
          ContextMenuButtonItem(
            onPressed: () {
              pasteCommand.execute(editorState);
              closeToolbar();
            },
            type: ContextMenuButtonType.paste,
          ),
          ContextMenuButtonItem(
            onPressed: () {
              final lastNode = editorState.document.root.children.last;
              editorState.selection = Selection(
                start: Position(path: [0]),
                end: Position(
                  path: [editorState.document.root.children.length - 1],
                  offset: lastNode.delta?.length ?? 0,
                ),
              );
              closeToolbar();
            },
            type: ContextMenuButtonType.selectAll,
          ),
        ],
      ).toList(),
    );
  }
}
