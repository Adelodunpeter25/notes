import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../database/database.dart' hide User;
import '../utils/note.dart';
import '../utils/time.dart';
import '../utils/dialogs.dart';
import '../theme.dart';
import 'app_bottom_sheet.dart';
import 'service_provider.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final bool isTrash;
  final VoidCallback? onRestore;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
    this.isTrash = false,
    this.onRestore,
  });

  String _formatDate(DateTime date) {
    return TimeUtils.formatCardTime(date);
  }

  String _getPreview(String content) {
    final lines = NoteUtils.extractLines(content);
    if (lines.isEmpty) return 'No additional text';
    final body = lines.skip(1).where((l) => l.trim().isNotEmpty).join(' ').trim();
    final text = body.isEmpty ? lines.join(' ').trim() : body;
    if (text.isEmpty) return 'No additional text';
    if (text.length > 100) return '${text.substring(0, 100)}…';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppSurfaces.surface(context);

    return Dismissible(
      key: ValueKey(note.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: isTrash ? AppColors.success : AppColors.accent,
        child: Icon(
          isTrash ? CupertinoIcons.arrow_uturn_left : CupertinoIcons.pin_fill,
          color: isTrash ? AppColors.onDestructive : AppColors.onAccent,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.destructive,
        child: const Icon(CupertinoIcons.trash_fill, color: AppColors.onDestructive),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (isTrash && onRestore != null) {
            onRestore!();
          } else {
            onPin();
          }
          return false;
        } else {
          final confirmed = await DialogUtils.showConfirmation(
            context: context,
            title: isTrash ? 'Delete Permanently?' : 'Delete Note?',
            message: isTrash
                ? 'Are you sure you want to permanently delete this note?'
                : 'This note will be moved to Trash.',
            primaryButtonText: 'Delete',
            isDestructive: true,
          );
          return confirmed;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            onLongPress: () => _showMoreActions(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTextColors.primary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isPinned)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            CupertinoIcons.pin_fill,
                            size: 14,
                            color: AppColors.accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDate(note.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTextColors.tertiary(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getPreview(note.content),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTextColors.secondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreActions(BuildContext context) {
    final services = ServiceProvider.of(context);

    AppBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isTrash) ...[
            ListTile(
              leading: Icon(
                note.isPinned ? CupertinoIcons.pin_slash_fill : CupertinoIcons.pin_fill,
              ),
              title: Text(note.isPinned ? 'Unpin Note' : 'Pin Note'),
              onTap: () {
                Navigator.pop(context);
                onPin();
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.folder),
              title: const Text('Move to Folder...'),
              onTap: () async {
                Navigator.pop(context);
                final folders = await services.db.select(services.db.folders).get();
                if (context.mounted) {
                  final currentFolder = folders.where((f) => f.id == note.folderId).firstOrNull;
                  final result = await DialogUtils.showFolderSelectionSheet(
                    context: context,
                    folders: folders,
                    initialFolder: currentFolder,
                  );
                  if (result != null && result.confirmed) {
                    await services.noteService.moveNoteToFolder(note, result.folder?.id);
                  }
                }
              },
            ),
          ] else ...[
            if (onRestore != null)
              ListTile(
                leading: const Icon(CupertinoIcons.arrow_uturn_left),
                title: const Text('Restore Note'),
                onTap: () {
                  Navigator.pop(context);
                  onRestore!();
                },
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(CupertinoIcons.trash, color: AppColors.destructive),
            title: Text(
              isTrash ? 'Delete Permanently' : 'Delete Note',
              style: const TextStyle(color: AppColors.destructive),
            ),
            onTap: () async {
              Navigator.pop(context);
              final confirmed = await DialogUtils.showConfirmation(
                context: context,
                title: isTrash ? 'Delete Permanently?' : 'Delete Note?',
                message: isTrash
                    ? 'Are you sure you want to permanently delete this note?'
                    : 'This note will be moved to Trash.',
                primaryButtonText: 'Delete',
                isDestructive: true,
              );
              if (confirmed) {
                onDelete();
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
