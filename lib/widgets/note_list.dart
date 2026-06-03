import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

/// Mobile-optimized note list with search, swipe actions, and a floating action button.
class NoteList extends StatelessWidget {
  final NoteFilter filter;
  final String folderName;
  final ValueChanged<Note> onNoteSelected;
  final VoidCallback onMenuPressed;
  final VoidCallback onNewNote;
  final VoidCallback onSync;

  const NoteList({
    super.key,
    required this.filter,
    required this.folderName,
    required this.onNoteSelected,
    required this.onMenuPressed,
    required this.onNewNote,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accentColor = Color(0xFFFFC107);

    return FutureBuilder<User?>(
      future: services.authService.getCurrentUser(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
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

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.line_horizontal_3),
              onPressed: onMenuPressed,
            ),
            title: Text(
              folderName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.arrow_2_circlepath),
                onPressed: onSync,
                tooltip: 'Sync',
              ),
            ],
          ),
          body: StreamBuilder<List<Note>>(
            stream: notesStream,
            builder: (context, noteSnapshot) {
              if (noteSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }

              final allNotes = noteSnapshot.data ?? [];
              if (allNotes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text,
                        size: 64,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        filter.type == NoteFilterType.trash
                            ? 'Trash is empty'
                            : 'No notes yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      if (filter.type != NoteFilterType.trash) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to create a new note',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              // Separate pinned and unpinned
              final pinnedNotes = allNotes.where((n) => n.isPinned).toList();
              final unpinnedNotes = allNotes.where((n) => !n.isPinned).toList();

              // Sort by updatedAt descending
              pinnedNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              unpinnedNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

              return CustomScrollView(
                slivers: [
                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: CupertinoSearchTextField(
                        placeholder: 'Search notes',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFE5E5EA),
                      ),
                    ),
                  ),

                  // Pinned section
                  if (pinnedNotes.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.pin_fill, size: 14, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              'Pinned',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.black54,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _NoteCard(
                          note: pinnedNotes[index],
                          onTap: () => onNoteSelected(pinnedNotes[index]),
                          onDelete: () => services.noteService.softDeleteNote(pinnedNotes[index]),
                          onPin: () => services.noteService.pinNote(pinnedNotes[index], !pinnedNotes[index].isPinned),
                          isTrash: filter.type == NoteFilterType.trash,
                          onRestore: filter.type == NoteFilterType.trash
                              ? () => services.noteService.restoreNote(pinnedNotes[index])
                              : null,
                        ),
                        childCount: pinnedNotes.length,
                      ),
                    ),
                  ],

                  // Notes section
                  if (unpinnedNotes.isNotEmpty) ...[
                    if (pinnedNotes.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                          child: Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _NoteCard(
                          note: unpinnedNotes[index],
                          onTap: () => onNoteSelected(unpinnedNotes[index]),
                          onDelete: () => services.noteService.softDeleteNote(unpinnedNotes[index]),
                          onPin: () => services.noteService.pinNote(unpinnedNotes[index], !unpinnedNotes[index].isPinned),
                          isTrash: filter.type == NoteFilterType.trash,
                          onRestore: filter.type == NoteFilterType.trash
                              ? () => services.noteService.restoreNote(unpinnedNotes[index])
                              : null,
                        ),
                        childCount: unpinnedNotes.length,
                      ),
                    ),
                  ],

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
          floatingActionButton: filter.type != NoteFilterType.trash
              ? FloatingActionButton(
                  onPressed: onNewNote,
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(CupertinoIcons.add, size: 28),
                )
              : null,
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final bool isTrash;
  final VoidCallback? onRestore;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
    this.isTrash = false,
    this.onRestore,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _getPreview(String content) {
    if (content.isEmpty) return 'No additional text';
    // Try to extract plain text from JSON content
    try {
      // Simple extraction - just show first portion
      final cleaned = content
          .replaceAll(RegExp(r'[{}\[\]":]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length > 100) return '${cleaned.substring(0, 100)}...';
      return cleaned.isEmpty ? 'No additional text' : cleaned;
    } catch (_) {
      return content.length > 100 ? '${content.substring(0, 100)}...' : content;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Dismissible(
      key: ValueKey(note.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: isTrash ? Colors.green : const Color(0xFFFFC107),
        child: Icon(
          isTrash ? CupertinoIcons.arrow_uturn_left : CupertinoIcons.pin_fill,
          color: isTrash ? Colors.white : Colors.black,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.destructiveRed,
        child: const Icon(CupertinoIcons.trash_fill, color: Colors.white),
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
          return true;
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
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: const Icon(
                            CupertinoIcons.pin_fill,
                            size: 14,
                            color: Color(0xFFFFC107),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDate(note.updatedAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getPreview(note.content),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black54,
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
}
