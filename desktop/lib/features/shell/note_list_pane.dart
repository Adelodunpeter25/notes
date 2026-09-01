import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/service_scope.dart';
import '../../app/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../data/database/database.dart' hide User;
import 'note_row.dart';

/// Middle pane: searchable, date-grouped note list with context menus.
///
/// Caches its Drift streams so selecting a note (which rebuilds Shell)
/// doesn't resubscribe and cause the whole list to flicker.
class NoteListPane extends StatefulWidget {
  final String userId;
  final String viewTitle;
  final bool isTrash;
  final String? folderId;
  final String searchQuery;
  final Note? selectedNote;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Note> onNoteSelected;
  final VoidCallback onNewNote;
  final VoidCallback onSync;
  final bool isSyncing;

  const NoteListPane({
    super.key,
    required this.userId,
    required this.viewTitle,
    required this.isTrash,
    this.folderId,
    required this.searchQuery,
    required this.selectedNote,
    required this.onSearchChanged,
    required this.onNoteSelected,
    required this.onNewNote,
    required this.onSync,
    required this.isSyncing,
  });

  @override
  State<NoteListPane> createState() => _NoteListPaneState();
}

class _NoteListPaneState extends State<NoteListPane> {
  Stream<List<Note>>? _notesStream;
  String? _boundUserId;
  bool? _boundIsTrash;
  String? _boundFolderId;
  ServiceScope? _boundScope;

  // Search debounce
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  String _lastNotifiedQuery = '';

  @override
  void initState() {
    super.initState();
    _lastNotifiedQuery = widget.searchQuery;
    _searchController.text = widget.searchQuery;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureStreams();
  }

  @override
  void didUpdateWidget(covariant NoteListPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
      _lastNotifiedQuery = widget.searchQuery;
    }
    _ensureStreams(force: oldWidget.userId != widget.userId ||
        oldWidget.isTrash != widget.isTrash ||
        oldWidget.folderId != widget.folderId);
  }

  void _ensureStreams({bool force = false}) {
    final scope = ServiceScope.of(context);
    final needsRebuild = force ||
        _boundUserId != widget.userId ||
        _boundIsTrash != widget.isTrash ||
        _boundFolderId != widget.folderId ||
        _boundScope != scope ||
        _notesStream == null;
    if (!needsRebuild) return;
    _boundUserId = widget.userId;
    _boundIsTrash = widget.isTrash;
    _boundFolderId = widget.folderId;
    _boundScope = scope;
    if (widget.isTrash) {
      _notesStream = scope.noteService.watchTrashNotes(widget.userId);
    } else if (widget.folderId != null) {
      _notesStream =
          scope.noteService.watchNotesInFolder(widget.userId, widget.folderId!);
    } else {
      _notesStream = scope.noteService.watchAllNotes(widget.userId);
    }
  }

  void _onSearchChanged(String raw) {
    // Cheap: update controller text is already done by the field; debounce the
    // notification to the parent so we don't rebuild Shell on every keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (raw != _lastNotifiedQuery) {
        _lastNotifiedQuery = raw;
        widget.onSearchChanged(raw);
      }
    });
    // If cleared via suffix button we want immediate clear.
    if (raw.isEmpty && _lastNotifiedQuery.isNotEmpty) {
      _searchDebounce?.cancel();
      _lastNotifiedQuery = '';
      widget.onSearchChanged('');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure streams reflect latest folder selection even if didChangeDependencies
    // hasn't fired yet due to parent setState ordering.
    _ensureStreams();
    return Container(
      color: AppSurfaces.background(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title, sync, new note
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.viewTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTextColors.primary(context),
                    ),
                  ),
                ),
                _SyncIconButton(onSync: widget.onSync, isSyncing: widget.isSyncing),
                IconButton(
                  icon: const Icon(Icons.note_add_outlined, size: 20),
                  tooltip: 'New Note',
                  onPressed: widget.isTrash ? null : widget.onNewNote,
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(
                  fontSize: 13, color: AppTextColors.primary(context)),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search notes',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
                filled: true,
                fillColor: AppSurfaces.elevated(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: widget.searchQuery.isNotEmpty
                ? _SearchResults(
                    userId: widget.userId,
                    query: widget.searchQuery,
                    selectedNote: widget.selectedNote,
                    onNoteSelected: widget.onNoteSelected,
                  )
                : _GroupedNoteList(
                    notesStream: _notesStream!,
                    isTrash: widget.isTrash,
                    selectedNote: widget.selectedNote,
                    onNoteSelected: widget.onNoteSelected,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SyncIconButton extends StatefulWidget {
  final VoidCallback onSync;
  final bool isSyncing;

  const _SyncIconButton({required this.onSync, required this.isSyncing});

  @override
  State<_SyncIconButton> createState() => _SyncIconButtonState();
}

class _SyncIconButtonState extends State<_SyncIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isSyncing) _controller.repeat();
  }

  @override
  void didUpdateWidget(_SyncIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSyncing != oldWidget.isSyncing) {
      widget.isSyncing ? _controller.repeat() : _controller.stop();
      if (!widget.isSyncing) _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        tooltip: 'Sync',
        onPressed: widget.isSyncing ? null : widget.onSync,
      ),
    );
  }
}

/// Stream-driven list grouped into Pinned + date sections.
/// Receives an already-cached stream so parent rebuilds don't flicker.
class _GroupedNoteList extends StatelessWidget {
  final Stream<List<Note>> notesStream;
  final bool isTrash;
  final Note? selectedNote;
  final ValueChanged<Note> onNoteSelected;

  const _GroupedNoteList({
    required this.notesStream,
    required this.isTrash,
    required this.selectedNote,
    required this.onNoteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Note>>(
      stream: notesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snapshot.data ?? const <Note>[];
        if (notes.isEmpty) {
          return Center(
            child: Text(
              isTrash ? 'Trash is empty' : 'No notes yet',
              style: TextStyle(color: AppTextColors.tertiary(context)),
            ),
          );
        }

        final pinned = isTrash
            ? <Note>[]
            : notes.where((n) => n.isPinned).toList();
        final unpinned =
            isTrash ? notes : notes.where((n) => !n.isPinned).toList();

        // Group by date section, preserving order.
        final sections = <String, List<Note>>{};
        for (final note in unpinned) {
          sections
              .putIfAbsent(TimeUtils.getNoteSection(note.updatedAt), () => [])
              .add(note);
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (pinned.isNotEmpty) ...[
              const _SectionHeader(label: 'Pinned'),
              for (final note in pinned)
                NoteRow(
                  key: ValueKey(note.id),
                  note: note,
                  isTrash: isTrash,
                  selected: selectedNote?.id == note.id,
                  onSelected: () => onNoteSelected(note),
                ),
            ],
            for (final entry in sections.entries) ...[
              _SectionHeader(label: entry.key),
              for (final note in entry.value)
                NoteRow(
                  key: ValueKey(note.id),
                  note: note,
                  isTrash: isTrash,
                  selected: selectedNote?.id == note.id,
                  onSelected: () => onNoteSelected(note),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Future-driven FTS search results with memoized future to avoid
/// re-querying on every parent rebuild.
class _SearchResults extends StatefulWidget {
  final String userId;
  final String query;
  final Note? selectedNote;
  final ValueChanged<Note> onNoteSelected;

  const _SearchResults({
    required this.userId,
    required this.query,
    required this.selectedNote,
    required this.onNoteSelected,
  });

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  late Future<List<Note>> _future;
  String _boundQuery = '';
  String _boundUserId = '';

  @override
  void initState() {
    super.initState();
    _boundQuery = widget.query;
    _boundUserId = widget.userId;
    _future = _doSearch();
  }

  @override
  void didUpdateWidget(covariant _SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.userId != widget.userId) {
      _boundQuery = widget.query;
      _boundUserId = widget.userId;
      _future = _doSearch();
    }
  }

  Future<List<Note>> _doSearch() {
    final scope = ServiceScope.of(context);
    return scope.noteService.searchNotes(_boundUserId, _boundQuery);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Note>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final results = snapshot.data ?? const <Note>[];
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No results for "${widget.query}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTextColors.tertiary(context)),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final note in results)
              NoteRow(
                key: ValueKey(note.id),
                note: note,
                isTrash: false,
                selected: widget.selectedNote?.id == note.id,
                onSelected: () => widget.onNoteSelected(note),
              ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppTextColors.secondary(context),
        ),
      ),
    );
  }
}
