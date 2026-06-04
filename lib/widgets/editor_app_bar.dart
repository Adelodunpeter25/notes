import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../database/database.dart' hide User;
import '../theme.dart';
import '../utils/dialogs.dart';
import 'service_provider.dart';

/// App bar for the note editor. Shows a back button, undo/redo controls, and
/// a Done button when the document has unsaved changes. The more-actions
/// bottom sheet (pin, move, checklist, delete) is handled internally.
class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final EditorState editorState;
  final Note note;
  final bool isDirty;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onBack;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onDone;
  final ValueChanged<Note>? onNoteChanged;

  const EditorAppBar({
    super.key,
    required this.editorState,
    required this.note,
    required this.isDirty,
    required this.canUndo,
    required this.canRedo,
    required this.onBack,
    required this.onUndo,
    required this.onRedo,
    required this.onDone,
    this.onNoteChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppSurfaces.surface(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chevron_left,
              color: AppColors.accent,
              size: 20,
            ),
            Text(
              'Notes',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 18,
              ),
            ),
          ],
        ),
        onPressed: onBack,
      ),
      leadingWidth: 100,
      actions: [
        IconButton(
          icon: const Icon(CupertinoIcons.arrow_uturn_left, size: 20),
          onPressed: canUndo ? onUndo : null,
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.arrow_uturn_right, size: 20),
          onPressed: canRedo ? onRedo : null,
        ),
        if (isDirty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              borderRadius: BorderRadius.circular(18),
              onPressed: onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
            onPressed: () => _showMoreActions(context),
          ),
      ],
    );
  }

  void _showMoreActions(BuildContext context) {
    final services = ServiceProvider.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            ListTile(
              leading: Icon(
                note.isPinned ? CupertinoIcons.pin_slash_fill : CupertinoIcons.pin_fill,
              ),
              title: Text(note.isPinned ? 'Unpin Note' : 'Pin Note'),
              onTap: () async {
                Navigator.pop(context);
                await services.noteService.pinNote(note, !note.isPinned);
                if (onNoteChanged != null) {
                  final fresh = await (services.db.select(services.db.notes)
                        ..where((t) => t.id.equals(note.id)))
                      .getSingle();
                  onNoteChanged!(fresh);
                }
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.folder),
              title: const Text('Move to Folder...'),
              onTap: () async {
                Navigator.pop(context);
                final folders = await services.db
                    .select(services.db.folders)
                    .get();
                if (context.mounted) {
                  final currentFolder = folders.where((f) => f.id == note.folderId).firstOrNull;
                  final result = await DialogUtils.showFolderSelectionDialog(
                    context: context,
                    folders: folders,
                    initialFolder: currentFolder,
                  );
                  if (result != null && result.confirmed) {
                    await services.noteService.moveNoteToFolder(note, result.folder?.id);
                    if (onNoteChanged != null) {
                      final fresh = await (services.db.select(services.db.notes)
                            ..where((t) => t.id.equals(note.id)))
                          .getSingle();
                      onNoteChanged!(fresh);
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.square_list),
              title: const Text('Toggle Checklist'),
              onTap: () {
                Navigator.pop(context);
                _toggleChecklist(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: AppColors.destructive),
              title: const Text('Delete Note', style: TextStyle(color: AppColors.destructive)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await DialogUtils.showConfirmation(
                  context: context,
                  title: 'Delete Note?',
                  message: 'This note will be moved to Trash.',
                  primaryButtonText: 'Delete',
                  isDestructive: true,
                );
                if (confirmed) {
                  await services.noteService.softDeleteNote(note);
                  onBack();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _toggleChecklist(BuildContext context) {
    final selection = editorState.selection;
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;
    final isTodoList = node.type == 'todo_list';
    editorState.formatNode(
      selection,
      (node) => node.copyWith(
        type: isTodoList ? ParagraphBlockKeys.type : 'todo_list',
        attributes: {
          'checked': false,
          blockComponentDelta: (node.delta ?? Delta()).toJson(),
        },
      ),
    );
  }
}
