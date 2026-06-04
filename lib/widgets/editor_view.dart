import 'dart:async';
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import '../utils/dialogs.dart';
import '../utils/note.dart';
import '../theme.dart';
import 'editor_toolbar.dart';

/// Full-screen mobile editor. The entire body is the AppFlowy editor; the
/// note title is derived from the first non-empty line of content. The
/// formatting toolbar only appears while the keyboard is visible.
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
  Timer? _debounceSave;
  StreamSubscription? _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _debounceSave?.cancel();
    super.dispose();
  }

  void _loadNote() {
    _transactionSubscription?.cancel();
    _debounceSave?.cancel();

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

  String _deriveTitle() {
    if (_editorState == null) return widget.note.title;
    final content = jsonEncode(_editorState!.document.toJson());
    return NoteUtils.titleFromContent(content);
  }

  Future<void> _saveNow() async {
    _debounceSave?.cancel();
    if (_editorState == null) return;
    final docMap = _editorState!.document.toJson();
    final newContent = jsonEncode(docMap);
    final newTitle = _deriveTitle();

    final updated = widget.note.copyWith(
      title: newTitle,
      content: newContent,
      updatedAt: DateTime.now(),
    );

    final services = ServiceProvider.of(context);
    await services.noteService.updateNote(updated);
    widget.onNoteUpdated?.call(updated);
  }

  void _triggerSave() {
    _debounceSave?.cancel();
    _debounceSave = Timer(const Duration(milliseconds: 500), _saveNow);
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

  bool get _isKeyboardVisible => MediaQuery.of(context).viewInsets.bottom > 0;

  Future<void> _handleBack() async {
    await _saveNow();
    widget.onBack();
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
          onPressed: _handleBack,
        ),
        leadingWidth: 100,
        title: Text(
          _formatDate(widget.note.createdAt),
          style: TextStyle(
            fontSize: 13,
            color: AppTextColors.tertiary(context),
          ),
        ),
        centerTitle: true,
        actions: [
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
          IconButton(
            icon: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
            onPressed: () => _showMoreActions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AppFlowyEditor(
              editorState: _editorState!,
              editorScrollController: EditorScrollController(
                editorState: _editorState!,
                shrinkWrap: true,
              ),
              editorStyle: EditorStyle.mobile(
                cursorColor: AppColors.accent,
                dragHandleColor: AppColors.accent,
                selectionColor: AppColors.accent.withOpacity(0.2),
                textStyleConfiguration: TextStyleConfiguration(
                  text: TextStyle(
                    fontSize: 16.0,
                    color: AppTextColors.primary(context),
                  ),
                  code: const TextStyle(
                    color: Colors.red,
                    backgroundColor: Color.fromARGB(98, 0, 195, 255),
                  ),
                ),
              ),
            ),
          ),
          if (_isKeyboardVisible)
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
