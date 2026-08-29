import 'package:flutter/material.dart';

import '../../app/service_scope.dart';
import '../../app/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../data/database/database.dart' hide User;
import 'note_row.dart';

/// Middle pane: searchable, date-grouped note list with context menus.
class NoteListPane extends StatelessWidget {
  final String userId;
  final String viewTitle;
  final bool isTrash;
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
    required this.searchQuery,
    required this.selectedNote,
    required this.onSearchChanged,
    required this.onNoteSelected,
    required this.onNewNote,
    required this.onSync,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
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
                    viewTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTextColors.primary(context),
                    ),
                  ),
                ),
                _SyncIconButton(onSync: onSync, isSyncing: isSyncing),
                IconButton(
                  icon: const Icon(Icons.note_add_outlined, size: 20),
                  tooltip: 'New Note',
                  onPressed: isTrash ? null : onNewNote,
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: onSearchChanged,
              style: TextStyle(
                  fontSize: 13, color: AppTextColors.primary(context)),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search notes',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => onSearchChanged(''),
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
            child: searchQuery.isNotEmpty
                ? _SearchResults(
                    userId: userId,
                    query: searchQuery,
                    selectedNote: selectedNote,
                    onNoteSelected: onNoteSelected,
                  )
                : _GroupedNoteList(
                    userId: userId,
                    isTrash: isTrash,
                    selectedNote: selectedNote,
                    onNoteSelected: onNoteSelected,
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
class _GroupedNoteList extends StatelessWidget {
  final String userId;
  final bool isTrash;
  final Note? selectedNote;
  final ValueChanged<Note> onNoteSelected;

  const _GroupedNoteList({
    required this.userId,
    required this.isTrash,
    required this.selectedNote,
    required this.onNoteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scope = ServiceScope.of(context);
    final stream = isTrash
        ? scope.noteService.watchTrashNotes(userId)
        : scope.noteService.watchAllNotes(userId);

    return StreamBuilder<List<Note>>(
      stream: stream,
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
              _SectionHeader(label: 'Pinned'),
              for (final note in pinned)
                NoteRow(
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

/// Future-driven FTS search results.
class _SearchResults extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scope = ServiceScope.of(context);
    return FutureBuilder<List<Note>>(
      future: scope.noteService.searchNotes(userId, query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final results = snapshot.data ?? const <Note>[];
        if (results.isEmpty) {
          return Center(
            child: Text(
              'No results for "$query"',
              style: TextStyle(color: AppTextColors.tertiary(context)),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final note in results)
              NoteRow(
                note: note,
                isTrash: false,
                selected: selectedNote?.id == note.id,
                onSelected: () => onNoteSelected(note),
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
