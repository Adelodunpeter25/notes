import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showMenu, RelativeRect, PopupMenuItem, PopupMenuDivider, PopupMenuEntry;
import 'package:macos_ui/macos_ui.dart';
import '../utils/dialogs.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import '../models/user.dart';

enum NoteFilterType { all, folder, trash }

class NoteFilter {
  final NoteFilterType type;
  final String? folderId;

  const NoteFilter.all() : type = NoteFilterType.all, folderId = null;
  const NoteFilter.folder(this.folderId) : type = NoteFilterType.folder;
  const NoteFilter.trash() : type = NoteFilterType.trash, folderId = null;
}

class NoteListPane extends StatelessWidget {
  final NoteFilter filter;
  final Note? selectedNote;
  final ValueChanged<Note> onNoteSelected;

  const NoteListPane({
    super.key,
    required this.filter,
    this.selectedNote,
    required this.onNoteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);

    return FutureBuilder<User?>(
      future: services.authService.getCurrentUser(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressCircle());
        }
        
        final user = userSnapshot.data;
        if (user == null) {
          return const Center(child: Text('Not logged in'));
        }

        // Determine notes stream based on filter
        final Stream<List<Note>> notesStream;
        switch (filter.type) {
          case NoteFilterType.all:
            notesStream = services.noteService.watchAllNotes(user.id);
            break;
          case NoteFilterType.folder:
            notesStream = services.noteService.watchNotesInFolder(user.id, filter.folderId!);
            break;
          case NoteFilterType.trash:
            notesStream = services.noteService.watchTrashNotes(user.id);
            break;
        }

        return StreamBuilder<List<Note>>(
          stream: notesStream,
          builder: (context, noteSnapshot) {
            if (noteSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: ProgressCircle());
            }

            final notes = noteSnapshot.data ?? [];
            if (notes.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No notes found',
                    style: TextStyle(color: CupertinoColors.systemGrey),
                  ),
                ),
              );
            }

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
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final isSelected = selectedNote?.id == note.id;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: GestureDetector(
                          onTap: () => onNoteSelected(note),
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
                                await services.noteService.softDeleteNote(note);
                              }
                            } else if (result == 'move' && context.mounted) {
                              // Fetch all folders
                              final folders = await services.db
                                  .select(services.db.folders)
                                  .get();

                              // Get note's current folder if applicable
                              Folder? currentFolder;
                              if (note.folderId != null) {
                                final matches = await (services.db.select(services.db.folders)
                                      ..where((t) => t.id.equals(note.folderId!)))
                                    .get();
                                if (matches.isNotEmpty) {
                                  currentFolder = matches.first;
                                }
                              }

                              if (context.mounted) {
                                final moveResult = await DialogUtils.showFolderSelectionDialog(
                                  context: context,
                                  folders: folders,
                                  initialFolder: currentFolder,
                                );

                                if (moveResult != null && moveResult.confirmed) {
                                  await services.noteService.moveNoteToFolder(
                                    note,
                                    moveResult.folder?.id,
                                  );
                                }
                              }
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? MacosTheme.of(context).dividerColor.withOpacity(0.4)
                                  : CupertinoColors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: MacosListTile(
                              title: Text(
                                note.title.isEmpty ? 'Untitled' : note.title,
                                style: MacosTheme.of(context).typography.headline.copyWith(
                                  color: isSelected ? CupertinoColors.white : null,
                                  fontWeight: isSelected ? FontWeight.bold : null,
                                ),
                              ),
                              subtitle: Text(
                                note.content.isEmpty ? 'No content' : note.content,
                                style: MacosTheme.of(context).typography.subheadline,
                              ),
                              onClick: () => onNoteSelected(note),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
