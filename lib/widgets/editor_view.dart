import 'dart:async';
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        TextField,
        InputDecoration,
        InputBorder;
import 'package:macos_ui/macos_ui.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import 'editor_toolbar.dart';

class EditorViewPane extends StatefulWidget {
  final Note? note;
  final ValueChanged<Note>? onNoteUpdated;

  const EditorViewPane({
    super.key,
    required this.note,
    this.onNoteUpdated,
  });

  @override
  State<EditorViewPane> createState() => _EditorViewPaneState();
}

class _EditorViewPaneState extends State<EditorViewPane> {
  EditorState? _editorState;
  final _titleController = TextEditingController();
  Timer? _debounceSave;
  StreamSubscription? _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void didUpdateWidget(covariant EditorViewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note?.id != oldWidget.note?.id) {
      _loadNote();
    } else if (widget.note != null && widget.note!.title != _titleController.text) {
      _titleController.text = widget.note!.title;
    }
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

    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      if (widget.note!.content.trim().isNotEmpty) {
        try {
          final docMap = jsonDecode(widget.note!.content) as Map<String, dynamic>;
          _editorState = EditorState(document: Document.fromJson(docMap));
        } catch (e) {
          _editorState = EditorState.blank();
        }
      } else {
        _editorState = EditorState.blank();
      }
      
      _transactionSubscription = _editorState!.transactionStream.listen((event) {
        if (event.$1 == TransactionTime.after) {
          _onContentChanged();
        }
      });
    } else {
      _editorState = null;
    }
  }

  void _onContentChanged() {
    _triggerSave();
  }

  void _triggerSave() {
    _debounceSave?.cancel();
    _debounceSave = Timer(const Duration(milliseconds: 500), () async {
      if (widget.note == null || _editorState == null) return;
      final docMap = _editorState!.document.toJson();
      final newContent = jsonEncode(docMap);
      final newTitle = _titleController.text;

      final updated = widget.note!.copyWith(
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

  @override
  Widget build(BuildContext context) {
    if (widget.note == null || _editorState == null) {
      return const Center(
        child: Text(
          'Select a note to edit',
          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
        ),
      );
    }

    final dividerColor = MacosTheme.of(context).dividerColor;

    return Column(
      children: [
        // 1. Windows Header (Notes, refresh, settings)
        _buildWindowHeader(context),
        Container(height: 0.5, color: dividerColor),

        // 2. Editor Sub-bar / Formatting toolbar
        _buildFormattingToolbar(context),
        Container(height: 0.5, color: dividerColor),

        // 3. Editor Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display note creation date
                Center(
                  child: Text(
                    _formatDate(widget.note!.createdAt),
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note Title Field
                TextField(
                  controller: _titleController,
                  onChanged: (_) => _triggerSave(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'New Note',
                    hintStyle: TextStyle(color: CupertinoColors.systemGrey3),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),

                // Editor Component
                AppFlowyEditor(
                  editorState: _editorState!,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWindowHeader(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'Notes',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.arrow_2_circlepath, size: 18),
            onPressed: () {
              // Sync manually
              final services = ServiceProvider.of(context);
              services.authService.getCurrentUser().then((u) {
                if (u != null) services.syncService.syncData(u.id);
              });
            },
          ),
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.settings, size: 18),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar(BuildContext context) {
    return EditorFormattingToolbar(
      editorState: _editorState!,
      isPinned: widget.note!.isPinned,
      onPinToggle: () {
        final services = ServiceProvider.of(context);
        services.noteService.pinNote(widget.note!, !widget.note!.isPinned);
      },
      onToggleChecklist: _toggleChecklist,
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minute $ampm';
  }
}
