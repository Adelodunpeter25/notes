import 'dart:async';
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import 'mobile_editor_toolbar.dart';

/// Full-screen mobile editor with AppFlowy editor, title field,
/// and a bottom formatting toolbar that sits above the keyboard.
class MobileEditorView extends StatefulWidget {
  final Note note;
  final VoidCallback onBack;
  final ValueChanged<Note>? onNoteUpdated;

  const MobileEditorView({
    super.key,
    required this.note,
    required this.onBack,
    this.onNoteUpdated,
  });

  @override
  State<MobileEditorView> createState() => _MobileEditorViewState();
}

class _MobileEditorViewState extends State<MobileEditorView> {
  EditorState? _editorState;
  final _titleController = TextEditingController();
  Timer? _debounceSave;
  StreamSubscription? _transactionSubscription;
  final ScrollController _scrollController = ScrollController();
  final bool _showToolbar = true;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _titleController.dispose();
    _debounceSave?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadNote() {
    _transactionSubscription?.cancel();
    _debounceSave?.cancel();

    _titleController.text = widget.note.title;
    if (widget.note.content.trim().isNotEmpty) {
      try {
        final docMap = jsonDecode(widget.note.content) as Map<String, dynamic>;
        _editorState = EditorState(document: Document.fromJson(docMap));
      } catch (e) {
        _editorState = EditorState.blank();
      }
    } else {
      _editorState = EditorState.blank();
    }

    _transactionSubscription = _editorState!.transactionStream.listen((event) {
      if (event.$1 == TransactionTime.after) {
        _triggerSave();
      }
    });
  }

  void _triggerSave() {
    _debounceSave?.cancel();
    _debounceSave = Timer(const Duration(milliseconds: 500), () async {
      if (_editorState == null) return;
      final docMap = _editorState!.document.toJson();
      final newContent = jsonEncode(docMap);
      final newTitle = _titleController.text;

      final updated = widget.note.copyWith(
        title: newTitle,
        content: newContent,
        updatedAt: DateTime.now(),
      );

      final services = ServiceProvider.of(context);
      await services.noteService.updateNote(updated);
      widget.onNoteUpdated?.call(updated);
    });
  }

  void _toggleChecklist() {
    if (_editorState == null) return;
    final selection = _editorState!.selection;
    if (selection == null) return;

    final node = _editorState!.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final isTodoList = node.type == 'todo_list';
    _editorState!.formatNode(
      selection,
      (node) => node.copyWith(
        type: isTodoList ? ParagraphBlockKeys.type : 'todo_list',
        attributes: {
          'checked': false,
          blockComponentDelta: (node.delta ?? Delta()).toJson(),
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    if (_editorState == null) {
      return const Scaffold(
        body: Center(child: CupertinoActivityIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    const accentColor = Color(0xFFFFC107);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.chevron_left,
                color: accentColor,
                size: 20,
              ),
              Text(
                'Notes',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          onPressed: widget.onBack,
        ),
        leadingWidth: 100,
        actions: [
          // Pin button
          IconButton(
            icon: Icon(
              widget.note.isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
              color: widget.note.isPinned ? accentColor : null,
              size: 20,
            ),
            onPressed: () {
              final services = ServiceProvider.of(context);
              services.noteService.pinNote(widget.note, !widget.note.isPinned);
            },
          ),
          // More actions
          IconButton(
            icon: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
            onPressed: () => _showMoreActions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Editor content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date
                  Center(
                    child: Text(
                      _formatDate(widget.note.createdAt),
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => _triggerSave(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'New Note',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 12),

                  // AppFlowy Editor
                  AppFlowyEditor(
                    editorState: _editorState!,
                    editorScrollController: EditorScrollController(
                      editorState: _editorState!,
                      shrinkWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Toolbar
          if (_showToolbar)
            MobileEditorToolbar(
              editorState: _editorState!,
              onToggleChecklist: _toggleChecklist,
            ),
        ],
      ),
    );
  }

  void _showMoreActions(BuildContext context) {
    final services = ServiceProvider.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                widget.note.isPinned ? CupertinoIcons.pin_slash_fill : CupertinoIcons.pin_fill,
              ),
              title: Text(widget.note.isPinned ? 'Unpin Note' : 'Pin Note'),
              onTap: () {
                Navigator.pop(context);
                services.noteService.pinNote(widget.note, !widget.note.isPinned);
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.folder),
              title: const Text('Move to Folder...'),
              onTap: () async {
                Navigator.pop(context);
                // Get folders
                final folders = await services.db
                    .select(services.db.folders)
                    .get();
                if (context.mounted) {
                  _showFolderPicker(context, folders, services);
                }
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.square_list),
              title: const Text('Toggle Checklist'),
              onTap: () {
                Navigator.pop(context);
                _toggleChecklist();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed),
              title: const Text('Delete Note', style: TextStyle(color: CupertinoColors.destructiveRed)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Note?'),
                    content: const Text('This note will be moved to Trash.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: CupertinoColors.destructiveRed),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await services.noteService.softDeleteNote(widget.note);
                  widget.onBack();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFolderPicker(BuildContext context, List<Folder> folders, ServiceProvider services) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Move to Folder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.folder),
              title: const Text('No Folder (Root)'),
              trailing: widget.note.folderId == null
                  ? const Icon(CupertinoIcons.checkmark, color: Color(0xFFFFC107))
                  : null,
              onTap: () {
                Navigator.pop(context);
                services.noteService.moveNoteToFolder(widget.note, null);
              },
            ),
            ...folders.map((folder) => ListTile(
                  leading: const Icon(CupertinoIcons.folder_fill, color: Color(0xFFFFC107)),
                  title: Text(folder.name),
                  trailing: widget.note.folderId == folder.id
                      ? const Icon(CupertinoIcons.checkmark, color: Color(0xFFFFC107))
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    services.noteService.moveNoteToFolder(widget.note, folder.id);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
