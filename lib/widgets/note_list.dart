import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import '../models/user.dart';
import '../theme.dart';
import '../utils/time.dart';
import '../utils/dialogs.dart';
import 'note_card.dart';
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
  final Future<void> Function() onSync;

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
  Future<List<Note>>? _searchFuture;
  bool _isLoading = true;
  Map<String, String> _folderNames = {};

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
    final services = ServiceProvider.of(context);
    final user = await services.authService.getCurrentUser();
    
    final foldersList = await services.db.select(services.db.folders).get();
    final folderNames = {for (var f in foldersList) f.id: f.name};

    if (mounted) {
      setState(() {
        _currentUser = user;
        _folderNames = folderNames;
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

  void _onSearchChanged(String value) {
    final q = value.trim();
    setState(() {
      _searchQuery = q;
      _searchFuture = q.isEmpty ? null : _performFtsSearch(q);
    });
    if (q.isEmpty) _searchFocusNode.unfocus();
  }

  Future<List<Note>> _performFtsSearch(String query) async {
    final services = ServiceProvider.of(context);
    return services.noteService.searchNotes(_currentUser!.id, query);
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
            RotatingSyncButton(onSync: widget.onSync),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CustomSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              placeholder: 'Search notes',
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _searchQuery.isNotEmpty
                ? FutureBuilder<List<Note>>(
                    future: _searchFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CupertinoActivityIndicator());
                      }
                      return _buildNoteListView(snapshot.data ?? [], isTrashView);
                    },
                  )
                : StreamBuilder<List<Note>>(
                    stream: _notesStream,
                    builder: (context, noteSnapshot) {
                      if (noteSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CupertinoActivityIndicator());
                      }
                      return _buildNoteListView(noteSnapshot.data ?? [], isTrashView);
                    },
                  ),
          ),
        ],
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
  Widget _buildNoteListView(List<Note> allNotes, bool isTrashView) {
    final services = ServiceProvider.of(context);

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
      );
    }

    allNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final pinnedNotes = allNotes.where((n) => n.isPinned).toList();
    final unpinnedNotes = allNotes.where((n) => !n.isPinned).toList();
    final groupedUnpinned = _groupNotes(unpinnedNotes);

    return CustomScrollView(
      slivers: [
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
                return NoteCard(
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
                  folderName: widget.filter.type == NoteFilterType.all && note.folderId != null
                      ? _folderNames[note.folderId]
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
                  return NoteCard(
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
                    folderName: widget.filter.type == NoteFilterType.all && note.folderId != null
                        ? _folderNames[note.folderId]
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
  }
}

class RotatingSyncButton extends StatefulWidget {
  final Future<void> Function() onSync;

  const RotatingSyncButton({super.key, required this.onSync});

  @override
  State<RotatingSyncButton> createState() => _RotatingSyncButtonState();
}

class _RotatingSyncButtonState extends State<RotatingSyncButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });
    _controller.repeat();
    try {
      await widget.onSync();
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: IconButton(
        icon: const Icon(CupertinoIcons.arrow_2_circlepath),
        onPressed: _handleSync,
        tooltip: 'Sync',
      ),
    );
  }
}
