import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showMenu, RelativeRect, PopupMenuItem, PopupMenuDivider, PopupMenuEntry;
import 'package:macos_ui/macos_ui.dart';
import '../utils/dialogs.dart';

class NoteListPane extends StatelessWidget {
  const NoteListPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CupertinoSearchTextField(
            placeholder: 'Search notes',
            style: MacosTheme.of(context).typography.body,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: GestureDetector(
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
                          value: 'pin',
                          height: 32,
                          child: Text('Pin Note', style: TextStyle(fontSize: 13)),
                        ),
                        const PopupMenuItem<String>(
                          value: 'move',
                          height: 32,
                          child: Text('Move to Folder...', style: TextStyle(fontSize: 13)),
                        ),
                        const PopupMenuDivider(height: 1),
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
                        title: 'Delete Note?',
                        message: 'Are you sure you want to move this note to the Trash?',
                        primaryButtonText: 'Delete',
                        isDestructive: true,
                      );
                      if (confirmed) {
                        // Soft delete logic
                      }
                    }
                  },
                  child: MacosListTile(
                    title: Text(
                      'Sample Note $index',
                      style: MacosTheme.of(context).typography.headline,
                    ),
                    subtitle: Text(
                      'This is a snippet of the note content...',
                      style: MacosTheme.of(context).typography.subheadline,
                    ),
                    onClick: () {},
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
