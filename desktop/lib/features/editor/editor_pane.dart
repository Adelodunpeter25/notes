import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../app/service_scope.dart';
import '../../app/theme.dart';
import '../../core/utils/note_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../data/database/database.dart' hide User;
import 'editor_toolbar.dart';

/// Right pane: the AppFlowy editor. Edits the canonical AppFlowy JSON
/// directly and persists through [NoteService] with debounced saves.
class EditorPane extends StatefulWidget {
  final Note? note;
  final ValueChanged<Note>? onNoteSaved;

  const EditorPane({super.key, required this.note, this.onNoteSaved});

  @override
  State<EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends State<EditorPane> {
  EditorState? _editorState;
  Timer? _debounceSave;
  StreamSubscription? _transactionSubscription;
  late final FocusNode _focusNode;
  late final EditorScrollController _editorScrollController;
  String _initialDocJson = '';
  bool _isDirty = false;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant EditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.note?.id;
    final newId = widget.note?.id;
    if (oldId != newId) {
      // Flush pending changes for the outgoing note before switching.
      _saveNow();
      _loadNote();
    }
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _debounceSave?.cancel();
    _focusNode.dispose();
    // EditorScrollController is owned by the EditorState lifecycle.
    super.dispose();
  }

  void _loadNote() {
    _transactionSubscription?.cancel();
    _debounceSave?.cancel();

    final content = widget.note?.content ?? '';
    if (content.trim().isNotEmpty) {
      try {
        final docMap = jsonDecode(content) as Map<String, dynamic>;
        _editorState = EditorState(document: Document.fromJson(docMap));
      } catch (_) {
        _editorState = EditorState.blank();
      }
    } else {
      _editorState = EditorState.blank();
    }

    _editorScrollController = EditorScrollController(editorState: _editorState!);
    _initialDocJson = jsonEncode(_editorState!.document.toJson());
    _isDirty = false;

    _transactionSubscription =
        _editorState!.transactionStream.listen((event) {
      if (event.$1 == TransactionTime.after) {
        final currentDocJson = jsonEncode(_editorState!.document.toJson());
        final isDirty = currentDocJson != _initialDocJson;
        if (isDirty) _triggerSave();
        if (isDirty != _isDirty && mounted) {
          setState(() => _isDirty = isDirty);
        }
      }
    });

    if (mounted) setState(() {});
  }

  void _triggerSave() {
    _debounceSave?.cancel();
    _debounceSave =
        Timer(const Duration(milliseconds: 800), _saveNow);
  }

  String get _currentDocJson =>
      jsonEncode(_editorState?.document.toJson() ?? {});

  Future<void> _saveNow() async {
    _debounceSave?.cancel();
    final editorState = _editorState;
    final note = widget.note;
    if (editorState == null || note == null || _savingNote) return;

    final newContent = _currentDocJson;
    final newTitle = NoteUtils.titleFromContent(newContent);

    // Only save if something actually changed to avoid touching updatedAt.
    if (newContent == _initialDocJson && newTitle == note.title) {
      if (mounted && _isDirty) setState(() => _isDirty = false);
      return;
    }

    _savingNote = true;
    try {
      final scope = ServiceScope.of(context);
      final fresh = await (scope.db.select(scope.db.notes)
            ..where((t) => t.id.equals(note.id)))
          .getSingle();

      final updated = fresh.copyWith(
        title: newTitle,
        content: newContent,
        updatedAt: DateTime.now(),
      );

      await scope.noteService.updateNote(updated);
      _initialDocJson = newContent;
      if (mounted) setState(() => _isDirty = false);
      widget.onNoteSaved?.call(updated);
    } finally {
      _savingNote = false;
    }
  }


  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    if (note == null || _editorState == null) {
      return Container(
        color: AppSurfaces.background(context),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.note_alt_outlined,
                  size: 48, color: AppTextColors.quaternary(context)),
              const SizedBox(height: 12),
              Text(
                'Select a note to begin',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTextColors.tertiary(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppSurfaces.background(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: date + dirty indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    TimeUtils.formatEditorHeader(note.updatedAt),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTextColors.tertiary(context),
                    ),
                  ),
                ),
                if (_isDirty)
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
          ),
          // Editor body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppFlowyEditor(
                editorState: _editorState!,
                focusNode: _focusNode,
                editorScrollController: _editorScrollController,
                editorStyle: EditorStyle.desktop(
                  cursorColor: AppColors.accent,
                  selectionColor: AppColors.accent.withValues(alpha: 0.2),
                  textStyleConfiguration: TextStyleConfiguration(
                    text: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppTextColors.primary(context),
                    ),
                    code: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: AppTextColors.primary(context),
                      backgroundColor: AppSurfaces.elevated(context),
                    ),
                    href: TextStyle(color: AppColors.accent),
                  ),
                ),
              ),
            ),
          ),
          DesktopEditorToolbar(editorState: _editorState!),
        ],
      ),
    );
  }
}
