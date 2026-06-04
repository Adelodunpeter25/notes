import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import '../models/user.dart';
import '../theme.dart';

enum NoteFilterType { all, folder, trash }

class NoteFilter {
  final NoteFilterType type;
  final String? folderId;

  const NoteFilter.all() : type = NoteFilterType.all, folderId = null;
  const NoteFilter.folder(this.folderId) : type = NoteFilterType.folder;
  const NoteFilter.trash() : type = NoteFilterType.trash, folderId = null;
}

/// Mobile-optimized note list with search, swipe actions, and a floating action button.
class NoteList extends StatefulWidget {
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
  State<NoteList> createState() => _NoteListState();
}

class _NoteListState extends State<NoteList> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Note note) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    if (note.title.toLowerCase().contains(q)) return true;
    final contentText = _extractText(note.content).toLowerCase();
    return contentText.contains(q);
  }

  String _extractText(String content) {
    if (content.isEmpty) return '';
    try {
      return content
          .replaceAll(RegExp(r'"\$?[a-zA-Z_]*":'), ' ')
          .replaceAll(RegExp(r'[{}\[\]"]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    } catch (_) {
      return content;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);

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

        final Stream<List<Note>> notesStream;
        switch (widget.filter.type) {
          case NoteFilterType.all:
            notesStream = services.noteService.watchAllNotes(user.id);
            break;
          case NoteFilterType.folder:
            notesStream = services.noteService.watchNotesInFolder(user.id, widget.filter.folderId!);
            break;
          case NoteFilterType.trash:
            notesStream = services.noteService.watchTrashNotes(user.id);
            break;
        }

        return Scaffold(
          backgroundColor: AppSurfaces.background(context),
          appBar: AppBar(
            backgroundColor: AppSurfaces.surface(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.line_horizontal_3),
              onPressed: widget.onMenuPressed,
            ),
            title: Text(
              widget.folderName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppTextColors.primary(context),
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.arrow_2_circlepath),
                onPressed: widget.onSync,
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

              final allNotes = (noteSnapshot.data ?? [])
                  .where(_matchesSearch)
                  .toList();
              if (allNotes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? CupertinoIcons.search
                            : CupertinoIcons.doc_text,
                        size: 64,
                        color: AppTextColors.quaternary(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No notes match "$_searchQuery"'
                            : widget.filter.type == NoteFilterType.trash
                                ? 'Trash is empty'
                                : 'No notes yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTextColors.tertiary(context),
                        ),
                      ),
                      if (_searchQuery.isEmpty && widget.filter.type != NoteFilterType.trash) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to create a new note',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTextColors.quaternary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              final pinnedNotes = allNotes.where((n) => n.isPinned).toList();
              final unpinnedNotes = allNotes.where((n) => !n.isPinned).toList();

              pinnedNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              unpinnedNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: 'Search notes',
                        style: TextStyle(
                          color: AppTextColors.primary(context),
                        ),
                        backgroundColor: AppSurfaces.elevated(context),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim();
                          });
                        },
                      ),
                    ),
                  ),

                  if (pinnedNotes.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.pin_fill, size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              'Pinned',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTextColors.secondary(context),
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
                          onTap: () => widget.onNoteSelected(pinnedNotes[index]),
                          onDelete: () => services.noteService.softDeleteNote(pinnedNotes[index]),
                          onPin: () => services.noteService.pinNote(pinnedNotes[index], !pinnedNotes[index].isPinned),
                          isTrash: widget.filter.type == NoteFilterType.trash,
                          onRestore: widget.filter.type == NoteFilterType.trash
                              ? () => services.noteService.restoreNote(pinnedNotes[index])
                              : null,
                        ),
                        childCount: pinnedNotes.length,
                      ),
                    ),
                  ],

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
                              color: AppTextColors.secondary(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _NoteCard(
                          note: unpinnedNotes[index],
                          onTap: () => widget.onNoteSelected(unpinnedNotes[index]),
                          onDelete: () => services.noteService.softDeleteNote(unpinnedNotes[index]),
                          onPin: () => services.noteService.pinNote(unpinnedNotes[index], !unpinnedNotes[index].isPinned),
                          isTrash: widget.filter.type == NoteFilterType.trash,
                          onRestore: widget.filter.type == NoteFilterType.trash
                              ? () => services.noteService.restoreNote(unpinnedNotes[index])
                              : null,
                        ),
                        childCount: unpinnedNotes.length,
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
          floatingActionButton: widget.filter.type != NoteFilterType.trash
              ? FloatingActionButton(
                  onPressed: widget.onNewNote,
                  backgroundColor: AppColors.accent,
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
    final cardColor = AppSurfaces.surface(context);

    return Dismissible(
      key: ValueKey(note.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: isTrash ? Colors.green : AppColors.accent,
        child: Icon(
          isTrash ? CupertinoIcons.arrow_uturn_left : CupertinoIcons.pin_fill,
          color: isTrash ? Colors.white : Colors.black,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.destructive,
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
                        _formatDate(note.updatedAt),
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
}
