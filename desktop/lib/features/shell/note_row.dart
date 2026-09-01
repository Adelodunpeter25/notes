import 'package:flutter/material.dart';

import '../../app/service_scope.dart';
import '../../app/theme.dart';
import '../../core/utils/note_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../data/database/database.dart' hide User;
import 'sidebar_helpers.dart';

/// A single note row in the note list, with a right-click context menu.
class NoteRow extends StatelessWidget {
  final Note note;
  final bool isTrash;
  final bool selected;
  final VoidCallback onSelected;

  const NoteRow({
    super.key,
    required this.note,
    required this.isTrash,
    required this.selected,
    required this.onSelected,
  });

  String _preview(String content) {
    final lines = NoteUtils.extractLines(content);
    if (lines.isEmpty) return 'No additional text';
    // Skip the first non-empty line (the title), show body only.
    final firstNonEmptyIndex = lines.indexWhere((l) => l.trim().isNotEmpty);
    final bodyStart = firstNonEmptyIndex == -1 ? 0 : firstNonEmptyIndex + 1;
    final body = lines
        .skip(bodyStart)
        .where((l) => l.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (body.isEmpty) return 'No additional text';
    if (body.length > 80) return '${body.substring(0, 80)}…';
    return body;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppSurfaces.surface(context),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onSelected,
          onSecondaryTapUp: (details) =>
              _showContextMenu(context, details.globalPosition),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (!isTrash && note.isPinned) ...[
                  Icon(Icons.push_pin, size: 12, color: AppColors.accent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTextColors.primary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _preview(note.content),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTextColors.secondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  TimeUtils.formatCardTime(note.updatedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTextColors.tertiary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension NoteRowActions on NoteRow {
  Future<void> _showContextMenu(
      BuildContext context, Offset position) async {
    final scope = ServiceScope.of(context);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        if (!isTrash) ...[
          PopupMenuItem(
            value: 'pin',
            child: Text(note.isPinned ? 'Unpin' : 'Pin'),
          ),
          const PopupMenuItem(
            value: 'move',
            child: Text('Move to Folder…'),
          ),
          const PopupMenuItem(value: 'trash', child: Text('Move to Trash')),
        ] else ...[
          const PopupMenuItem(value: 'restore', child: Text('Restore')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete Permanently'),
          ),
        ],
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'pin':
        await scope.noteService.pinNote(note, !note.isPinned);
        break;
      case 'move':
        // Only show non-deleted folders.
        final folders = await (scope.db.select(scope.db.folders)
              ..where((t) => t.deletedAt.isNull()))
            .get();
        if (!context.mounted) return;
        final rawFolderId = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Move to Folder'),
            children: [
              for (final folder in folders)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, folder.id),
                  child: Text(folder.name),
                ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('No Folder'),
              ),
            ],
          ),
        );
        if (rawFolderId == null) break; // dismissed
        final String? targetFolderId = rawFolderId.isEmpty ? null : rawFolderId;
        if (targetFolderId != note.folderId) {
          await scope.noteService.moveNoteToFolder(note, targetFolderId);
        }
        break;
      case 'trash':
        await scope.noteService.softDeleteNote(note);
        break;
      case 'restore':
        await scope.noteService.restoreNote(note);
        break;
      case 'delete':
        final confirmed = await confirmDialog(
          context,
          title: 'Delete Permanently?',
          message: 'This note will be deleted forever. This cannot be undone.',
        );
        if (confirmed == true) {
          await scope.noteService.deleteNotePermanently(note);
        }
        break;
    }
  }
}
