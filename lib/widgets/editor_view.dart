import 'dart:async';
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/service_provider.dart';
import '../database/database.dart' hide User;
import '../utils/note.dart';
import '../theme.dart';
import 'editor_app_bar.dart';
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
  late final FocusNode _focusNode;
  String _initialDocJson = '';
  bool _isDirty = false;
  bool _canUndo = false;
  bool _canRedo = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _loadNote();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _debounceSave?.cancel();
    _focusNode.dispose();
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

    _initialDocJson = jsonEncode(_editorState!.document.toJson());
    _isDirty = false;
    _canUndo = false;
    _canRedo = false;

    _transactionSubscription = _editorState!.transactionStream.listen((event) {
      if (event.$1 == TransactionTime.after) {
        _triggerSave();
        final canUndo = _editorState!.undoManager.undoStack.isNonEmpty;
        final canRedo = _editorState!.undoManager.redoStack.isNonEmpty;
        final currentDocJson = jsonEncode(_editorState!.document.toJson());
        final isDirty = currentDocJson != _initialDocJson;
        if (canUndo != _canUndo || canRedo != _canRedo || isDirty != _isDirty) {
          if (mounted) {
            setState(() {
              _canUndo = canUndo;
              _canRedo = canRedo;
              _isDirty = isDirty;
            });
          }
        }
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

    final services = ServiceProvider.of(context);
    final fresh = await (services.db.select(services.db.notes)
          ..where((t) => t.id.equals(widget.note.id)))
        .getSingle();

    final updated = fresh.copyWith(
      title: newTitle,
      content: newContent,
      updatedAt: DateTime.now(),
    );

    await services.noteService.updateNote(updated);
    _initialDocJson = jsonEncode(_editorState!.document.toJson());
    if (mounted) setState(() => _isDirty = false);
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

  Future<void> _handleBack() async {
    _debounceSave?.cancel();
    _focusNode.unfocus();
    await _saveNow();
    widget.onBack();
  }

  void _onUndo() {
    _editorState?.undoManager.undo();
    if (mounted) {
      setState(() {
        _canUndo = _editorState!.undoManager.undoStack.isNonEmpty;
        _canRedo = _editorState!.undoManager.redoStack.isNonEmpty;
      });
    }
  }

  void _onRedo() {
    _editorState?.undoManager.redo();
    if (mounted) {
      setState(() {
        _canUndo = _editorState!.undoManager.undoStack.isNonEmpty;
        _canRedo = _editorState!.undoManager.redoStack.isNonEmpty;
      });
    }
  }

  Future<void> _onDone() async {
    await _saveNow();
  }

  void _onNoteChanged(Note fresh) {
    widget.onNoteUpdated?.call(fresh);
  }

  @override
  Widget build(BuildContext context) {
    if (_editorState == null) {
      return const Scaffold(
        body: Center(child: CupertinoActivityIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppSurfaces.background(context),
        appBar: EditorAppBar(
          editorState: _editorState!,
          note: widget.note,
          isDirty: _isDirty,
          canUndo: _canUndo,
          canRedo: _canRedo,
          onBack: _handleBack,
          onUndo: _onUndo,
          onRedo: _onRedo,
          onDone: _onDone,
          onNoteChanged: _onNoteChanged,
        ),
        body: Column(
          children: [
            Expanded(
              child: AppFlowyEditor(
                editorState: _editorState!,
                focusNode: _focusNode,
                editorScrollController: EditorScrollController(
                  editorState: _editorState!,
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
                    code: TextStyle(
                      fontFamily: 'monospace',
                      color: AppTextColors.primary(context),
                      backgroundColor: AppSurfaces.elevated(context),
                    ),
                  ),
                ),
              ),
            ),
            EditorToolbar(
              editorState: _editorState!,
              onToggleChecklist: _toggleChecklist,
            ),
          ],
        ),
      ),
    );
  }
}
