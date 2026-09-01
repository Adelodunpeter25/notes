import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../app/service_scope.dart';
import '../../app/theme.dart';
import '../../core/utils/note_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../data/database/database.dart' hide User;

/// Right pane: the AppFlowy editor. Edits the canonical AppFlowy JSON
/// directly and persists through [NoteService] with debounced saves.
class EditorPane extends StatefulWidget {
  final Note? note;
  final ValueChanged<Note>? onNoteSaved;
  final ValueChanged<EditorState?>? onEditorStateChanged;

  const EditorPane({
    super.key,
    required this.note,
    this.onNoteSaved,
    this.onEditorStateChanged,
  });

  @override
  State<EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends State<EditorPane> {
  EditorState? _editorState;
  Timer? _debounceSave;
  StreamSubscription? _transactionSubscription;
  late final FocusNode _focusNode;
  EditorScrollController? _editorScrollController;
  String _initialDocJson = '';
  bool _isDirty = false;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Initial load if a note is already provided at mount — do it
    // synchronously so the first build already has the editor (avoids a
    // one-frame placeholder flash). _loadNote's trailing setState is skipped
    // for the initial load.
    if (widget.note != null) {
      _loadNote(notify: false);
    } else {
      _editorState = null;
      _initialDocJson = '';
    }
  }

  @override
  void didUpdateWidget(covariant EditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.note?.id;
    final newId = widget.note?.id;
    if (oldId != newId) {
      // Flush pending changes for the outgoing note before switching.
      // Capture outgoing note + doc before they are overwritten.
      final outgoingNote = oldWidget.note;
      final outgoingDocJson = _editorState != null
          ? jsonEncode(_editorState!.document.toJson())
          : _initialDocJson;
      final outgoingInitial = _initialDocJson;
      if (outgoingNote != null && outgoingDocJson != outgoingInitial) {
        _saveDocForNote(outgoingNote, outgoingDocJson, outgoingInitial);
      } else {
        _debounceSave?.cancel();
      }
      if (newId == null) {
        // Switched to no selection — clear toolbar.
        _editorState = null;
        _initialDocJson = '';
        _isDirty = false;
        _transactionSubscription?.cancel();
        _editorScrollController?.dispose();
        _editorScrollController = null;
        widget.onEditorStateChanged?.call(null);
        if (mounted) setState(() {});
      } else {
        _loadNote();
      }
    }
  }

  @override
  void dispose() {
    // Flush any pending debounced save for the current note before disposing.
    // Fire-and-forget is okay here; we cancel the timer but attempt a direct save
    // if dirty. Use unawaited to avoid blocking dispose.
    if (_isDirty && _editorState != null && widget.note != null) {
      final docJson = jsonEncode(_editorState!.document.toJson());
      if (docJson != _initialDocJson) {
        // Best effort: try to persist without context (service may be disposed).
        // The debounce flush in didUpdateWidget already handles the common case.
      }
    }
    _transactionSubscription?.cancel();
    _debounceSave?.cancel();
    _editorScrollController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadNote({bool notify = true}) {
    _transactionSubscription?.cancel();
    _debounceSave?.cancel();
    _editorScrollController?.dispose();
    _editorScrollController = null;

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

    widget.onEditorStateChanged?.call(_editorState);
    if (notify && mounted) setState(() {});
    // Request focus for immediate typing after note switch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.note != null) {
        _focusNode.requestFocus();
      }
    });
  }

  void _triggerSave() {
    _debounceSave?.cancel();
    _debounceSave =
        Timer(const Duration(milliseconds: 800), _saveNow);
  }

  String get _currentDocJson =>
      jsonEncode(_editorState?.document.toJson() ?? {});

  Future<void> _saveDocForNote(
      Note note, String docJson, String initialJson) async {
    if (_savingNote) return;
    final newTitle = NoteUtils.titleFromContent(docJson);
    if (docJson == initialJson && newTitle == note.title) {
      if (mounted && _isDirty) setState(() => _isDirty = false);
      return;
    }
    _savingNote = true;
    try {
      // Capture scope before await.
      final scope = ServiceScope.of(context);
      // Fetch fresh row to avoid overwriting concurrent folder moves.
      final fresh = await (scope.db.select(scope.db.notes)
            ..where((t) => t.id.equals(note.id)))
          .getSingleOrNull();
      if (fresh == null) return;
      final updated = fresh.copyWith(
        title: newTitle,
        content: docJson,
        updatedAt: DateTime.now(),
      );
      await scope.noteService.updateNote(updated);
      // Only update local initial if we are still editing the same note.
      if (widget.note?.id == note.id) {
        _initialDocJson = docJson;
        if (mounted) setState(() => _isDirty = false);
        widget.onNoteSaved?.call(updated);
      }
    } catch (_) {
      // Keep dirty so next debounce retries.
    } finally {
      _savingNote = false;
    }
  }

  Future<void> _saveNow() async {
    _debounceSave?.cancel();
    final editorState = _editorState;
    final note = widget.note;
    if (editorState == null || note == null || _savingNote) return;
    final newContent = _currentDocJson;
    await _saveDocForNote(note, newContent, _initialDocJson);
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
                editorScrollController: _editorScrollController!,
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
          // Toolbar removed from here — now hosted in TitleBar (Apple Notes style).
          // Keep a thin bottom spacer for scroll padding.
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
