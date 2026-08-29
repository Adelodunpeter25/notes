import 'package:flutter/material.dart';

import '../data/repositories/note_repository.dart';
import '../domain/models/folder.dart';
import '../domain/models/note.dart';

class NoteDesktopApp extends StatelessWidget {
  const NoteDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const NotesShell(),
    );
  }
}

class NotesShell extends StatefulWidget {
  const NotesShell({super.key});

  @override
  State<NotesShell> createState() => _NotesShellState();
}

class _NotesShellState extends State<NotesShell> {
  final NoteRepository _repository = NoteRepository();
  String _selectedView = 'All Notes';
  Note? _selectedNote;
  String _query = '';

  List<Note> get _visibleNotes {
    final notes = _query.isEmpty ? _repository.activeNotes : _repository.search(_query);
    if (_selectedView == 'Trash') return _repository.trashNotes;
    if (_selectedView == 'All Notes') return notes;
    final folder = _repository.folders.where((item) => item.name == _selectedView).firstOrNull;
    return folder == null ? const [] : notes.where((note) => note.folderId == folder.id).toList();
  }

  void _createNote() {
    if (_selectedView == 'Trash') return;
    final folder = _repository.folders.where((item) => item.name == _selectedView).firstOrNull;
    final note = _repository.createNote(folderId: folder?.id);
    setState(() => _selectedNote = note);
  }

  void _createFolder() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) _repository.createFolder(name);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 220, child: _Sidebar(
            selectedView: _selectedView,
            folders: _repository.folders,
            onSelect: (view) => setState(() { _selectedView = view; _selectedNote = null; }),
            onCreateFolder: _createFolder,
          )),
          const VerticalDivider(width: 1),
          SizedBox(width: 320, child: _NoteList(
            notes: _visibleNotes,
            selectedNote: _selectedNote,
            query: _query,
            canCreate: _selectedView != 'Trash',
            onQueryChanged: (query) => setState(() => _query = query),
            onCreate: _createNote,
            onSelect: (note) => setState(() => _selectedNote = note),
          )),
          const VerticalDivider(width: 1),
          Expanded(child: _Editor(
            note: _selectedNote,
            onChanged: (value) {
              final note = _selectedNote;
              if (note == null) return;
              setState(() {
                note.title = value.$1;
                note.document = value.$2;
                note.updatedAt = DateTime.now();
                _repository.updateNote(note);
              });
            },
          )),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedView, required this.folders, required this.onSelect, required this.onCreateFolder});
  final String selectedView;
  final List<Folder> folders;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.all(20), child: Text('Note', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      _item(Icons.notes, 'All Notes'),
      _item(Icons.delete_outline, 'Trash'),
      const Divider(),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Folders', style: TextStyle(fontWeight: FontWeight.bold)),
        IconButton(onPressed: onCreateFolder, icon: const Icon(Icons.add, size: 18)),
      ])),
      ...folders.map((folder) => _item(Icons.folder_outlined, folder.name)),
    ]),
  );

  Widget _item(IconData icon, String label) => ListTile(
    selected: selectedView == label,
    leading: Icon(icon),
    title: Text(label),
    onTap: () => onSelect(label),
  );
}

class _NoteList extends StatelessWidget {
  const _NoteList({required this.notes, required this.selectedNote, required this.query, required this.canCreate, required this.onQueryChanged, required this.onCreate, required this.onSelect});
  final List<Note> notes;
  final Note? selectedNote;
  final String query;
  final bool canCreate;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCreate;
  final ValueChanged<Note> onSelect;

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(12, 16, 12, 8), child: Row(children: [
      Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search', border: OutlineInputBorder()), onChanged: onQueryChanged)),
      const SizedBox(width: 8),
      IconButton(onPressed: canCreate ? onCreate : null, icon: const Icon(Icons.add)),
    ])),
    Expanded(child: notes.isEmpty ? const Center(child: Text('No notes')) : ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return ListTile(selected: note.id == selectedNote?.id, title: Text(note.title.isEmpty ? 'Untitled' : note.title), subtitle: Text(note.document.isEmpty ? 'Empty note' : note.document, maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () => onSelect(note));
      },
    )),
  ]);
}

class _Editor extends StatefulWidget {
  const _Editor({required this.note, required this.onChanged});
  final Note? note;
  final ValueChanged<(String, String)> onChanged;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final TextEditingController _titleController;
  late final TextEditingController _documentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _documentController = TextEditingController();
    _loadNote();
  }

  @override
  void didUpdateWidget(covariant _Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note?.id != widget.note?.id) _loadNote();
  }

  void _loadNote() {
    _titleController.text = widget.note?.title ?? '';
    _documentController.text = widget.note?.document ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.note == null) return const Center(child: Text('Select a note to begin'));
    return Padding(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _titleController, style: Theme.of(context).textTheme.headlineMedium, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Untitled'), onChanged: (_) => _emit()),
      const Divider(),
      Expanded(child: TextField(controller: _documentController, expands: true, maxLines: null, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Start writing…'), onChanged: (_) => _emit())),
    ]));
  }

  void _emit() => widget.onChanged((_titleController.text, _documentController.text));

  @override
  void dispose() {
    _titleController.dispose();
    _documentController.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
