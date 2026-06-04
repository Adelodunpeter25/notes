import 'dart:async';
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import '../utils/dialogs.dart';
import '../theme.dart';
import 'editor_toolbar.dart';

/// Full-screen mobile editor with AppFlowy editor, title field,
/// and a bottom formatting toolbar that sits above the keyboard.
class EditorView extends StatefulWidget {
  final Note note;
  final VoidCallback onBack;
  final ValueChanged<Note>? onNoteUpdated;

  const EditorView({
    super.key,
    required this.note,
    required this.onBack,
    this.onNoteUpdated,
  });

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  EditorState? _editorState;
  final _titleController = TextEditingController();
  Timer? _debounceSave;
  StreamSubscription? _transactionSubscription;
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
                'Notes',
                style: TextStyle(
                  color: AppColors.accent,
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
              color: widget.note.isPinned ? AppColors.accent : null,
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
          // Fixed header: date + title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    _formatDate(widget.note.createdAt),
                    style: TextStyle(
                      color: AppTextColors.tertiary(context),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  onChanged: (_) => _triggerSave(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTextColors.primary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'New Note',
                    hintStyle: TextStyle(
                      color: AppTextColors.quaternary(context),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: AppSurfaces.divider(context),
                ),
              ],
            ),
          ),

          // AppFlowy Editor fills remaining space with its own scrolling
          Expanded(
            child: AppFlowyEditor(
              editorState: _editorState!,
              editorScrollController: EditorScrollController(
                editorState: _editorState!,
              ),
            ),
          ),

          // Bottom Toolbar
          if (_showToolbar)
            EditorToolbar(
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
                final folders = await services.db
                    .select(services.db.folders)
                    .get();
                if (context.mounted) {
                  final currentFolder = folders.where((f) => f.id == widget.note.folderId).firstOrNull;
                  final result = await DialogUtils.showFolderSelectionDialog(
                    context: context,
                    folders: folders,
                    initialFolder: currentFolder,
                  );
                  if (result != null && result.confirmed) {
                    await services.noteService.moveNoteToFolder(widget.note, result.folder?.id);
                  }
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
              leading: const Icon(CupertinoIcons.trash, color: AppColors.destructive),
              title: const Text('Delete Note', style: TextStyle(color: AppColors.destructive)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await DialogUtils.showConfirmation(
                  context: context,
                  title: 'Delete Note?',
                  message: 'This note will be moved to Trash.',
                  primaryButtonText: 'Delete',
                  isDestructive: true,
                );
                if (confirmed) {
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
}
