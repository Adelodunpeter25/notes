import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import '../models/user.dart';
import '../theme.dart';
import '../utils/note.dart';
import '../utils/time.dart';
import '../utils/dialogs.dart';
import 'search_bar.dart';

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
  final _searchFocusNode = FocusNode();
  User? _currentUser;
  Stream<List<Note>>? _notesStream;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  @override
  void didUpdateWidget(NoteList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.type != widget.filter.type || oldWidget.filter.folderId != widget.filter.folderId) {
      _initNotesStream();
    }
  }

  Future<void> _loadData() async {
    if (_currentUser != null) return;
    final services = ServiceProvider.of(context);
    final user = await services.authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
        _initNotesStream();
      });
    }
  }

  void _initNotesStream() {
    if (_currentUser == null) return;
    final services = ServiceProvider.of(context);
    setState(() {
      switch (widget.filter.type) {
        case NoteFilterType.all:
          _notesStream = services.noteService.watchAllNotes(_currentUser!.id);
          break;
        case NoteFilterType.folder:
          _notesStream = services.noteService.watchNotesInFolder(_currentUser!.id, widget.filter.folderId!);
          break;
        case NoteFilterType.trash:
          _notesStream = services.noteService.watchTrashNotes(_currentUser!.id);
          break;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _matchesSearch(Note note) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    if (note.title.toLowerCase().contains(q)) return true;
    final body = NoteUtils.extractLines(note.content).join(' ').toLowerCase();
    return body.contains(q);
  }

  Map<String, List<Note>> _groupNotes(List<Note> notesList) {
    final Map<String, List<Note>> grouped = {
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Last Month': [],
      'Last Year': [],
      'Older': [],
    };

    for (final note in notesList) {
      final section = TimeUtils.getNoteSection(note.createdAt);
      grouped[section]?.add(note);
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final isTrashView = widget.filter.type == NoteFilterType.trash;

    return Scaffold(
      backgroundColor: AppSurfaces.background(context),
      appBar: AppBar(
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
                'Folders',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          onPressed: widget.onMenuPressed,
        ),
        leadingWidth: 100,
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
          if (isTrashView)
            TextButton(
              onPressed: () async {
                final confirmed = await DialogUtils.showConfirmation(
                  context: context,
                  title: 'Empty Trash?',
                  message: 'Are you sure you want to permanently delete all notes in Trash? This action cannot be undone.',
                  primaryButtonText: 'Empty Trash',
                  isDestructive: true,
                );
                if (confirmed) {
                  await services.noteService.emptyTrash(_currentUser!.id);
                }
              },
              child: const Text(
                'Empty',
                style: TextStyle(
                  color: AppColors.destructive,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(CupertinoIcons.arrow_2_circlepath),
              onPressed: widget.onSync,
              tooltip: 'Sync',
            ),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: _notesStream,
        builder: (context, noteSnapshot) {
          if (noteSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          final allNotes = (noteSnapshot.data ?? [])
              .where(_matchesSearch)
              .toList();

          if (allNotes.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: CustomSearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      placeholder: 'Search notes',
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                        if (value.isEmpty) _searchFocusNode.unfocus();
                      },
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
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
                              : isTrashView
                                  ? 'Trash is empty'
                                  : 'No notes yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppTextColors.tertiary(context),
                          ),
                        ),
                        if (_searchQuery.isEmpty && !isTrashView) ...[
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
                  ),
                ),
              ],
            );
          }

          // Sort by creation date descending
          allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final pinnedNotes = allNotes.where((n) => n.isPinned).toList();
          final unpinnedNotes = allNotes.where((n) => !n.isPinned).toList();

          final groupedUnpinned = _groupNotes(unpinnedNotes);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: CustomSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    placeholder: 'Search notes',
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                      if (value.isEmpty) _searchFocusNode.unfocus();
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
                    (context, index) {
                      final note = pinnedNotes[index];
                      return _NoteCard(
                        note: note,
                        onTap: () => widget.onNoteSelected(note),
                        onDelete: isTrashView
                            ? () => services.noteService.deleteNotePermanently(note)
                            : () => services.noteService.softDeleteNote(note),
                        onPin: () => services.noteService.pinNote(note, !note.isPinned),
                        isTrash: isTrashView,
                        onRestore: isTrashView
                            ? () => services.noteService.restoreNote(note)
                            : null,
                      );
                    },
                    childCount: pinnedNotes.length,
                  ),
                ),
              ],

              ...groupedUnpinned.entries.expand((entry) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                      child: Text(
                        entry.key,
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
                      (context, index) {
                        final note = entry.value[index];
                        return _NoteCard(
                          note: note,
                          onTap: () => widget.onNoteSelected(note),
                          onDelete: isTrashView
                              ? () => services.noteService.deleteNotePermanently(note)
                              : () => services.noteService.softDeleteNote(note),
                          onPin: () => services.noteService.pinNote(note, !note.isPinned),
                          isTrash: isTrashView,
                          onRestore: isTrashView
                              ? () => services.noteService.restoreNote(note)
                              : null,
                        );
                      },
                      childCount: entry.value.length,
                    ),
                  ),
                ];
              }),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: !isTrashView
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
}
