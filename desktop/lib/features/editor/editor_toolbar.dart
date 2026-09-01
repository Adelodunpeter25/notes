import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Desktop formatting toolbar docked above the editor. Mirrors the Swift
/// app's EditorToolbar: bold/italic/underline/strikethrough, Title/Heading/
/// Subheading, checkbox, bullet and numbered lists.
class DesktopEditorToolbar extends StatefulWidget {
  final EditorState editorState;
  /// When true the toolbar renders without its own background/border so it
  /// can be embedded in the window title bar (Apple Notes style).
  final bool embedded;

  const DesktopEditorToolbar({
    super.key,
    required this.editorState,
    this.embedded = false,
  });

  @override
  State<DesktopEditorToolbar> createState() => _DesktopEditorToolbarState();
}

class _DesktopEditorToolbarState extends State<DesktopEditorToolbar> {
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isStrikethrough = false;
  String _activeBlockType = 'paragraph';
  int _activeHeadingLevel = 0;

  @override
  void initState() {
    super.initState();
    _updateState();
    widget.editorState.toggledStyleNotifier.addListener(_onStateChanged);
    widget.editorState.selectionNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.editorState.toggledStyleNotifier.removeListener(_onStateChanged);
    widget.editorState.selectionNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(_updateState);
  }

  void _updateState() {
    final selection = widget.editorState.selection;
    if (selection == null) return;

    final toggled = widget.editorState.toggledStyle;
    _isBold = toggled.containsKey(AppFlowyRichTextKeys.bold);
    _isItalic = toggled.containsKey(AppFlowyRichTextKeys.italic);
    _isUnderline = toggled.containsKey(AppFlowyRichTextKeys.underline);
    _isStrikethrough = toggled.containsKey(AppFlowyRichTextKeys.strikethrough);

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node != null) {
      _activeBlockType = node.type;
      _activeHeadingLevel = node.type == HeadingBlockKeys.type
          ? node.attributes[HeadingBlockKeys.level] as int? ?? 0
          : 0;
    }
  }

  void _toggleInline(String key) {
    widget.editorState.toggleAttribute(key);
    _updateState();
  }

  void _toggleBlock(String blockType, [Map<String, dynamic>? attributes]) {
    final selection = widget.editorState.selection;
    if (selection == null) return;

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final isAlreadyType = node.type == blockType &&
        (attributes == null ||
            node.attributes[HeadingBlockKeys.level] ==
                attributes[HeadingBlockKeys.level]);

    widget.editorState.formatNode(
      selection,
      (node) => node.copyWith(
        type: isAlreadyType ? ParagraphBlockKeys.type : blockType,
        attributes: {
          ...?attributes,
          blockComponentDelta: (node.delta ?? Delta()).toJson(),
        },
      ),
    );
  }

  void _toggleHeading(int level) =>
      _toggleBlock(HeadingBlockKeys.type, {HeadingBlockKeys.level: level});

  @override
  Widget build(BuildContext context) => _ToolbarScaffold(state: this, embedded: widget.embedded);
}

class _ToolbarScaffold extends StatelessWidget {
  final _DesktopEditorToolbarState state;
  final bool embedded;

  const _ToolbarScaffold({required this.state, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _ToolbarButton(
          label: 'B',
          isBold: true,
          active: state._isBold,
          tooltip: 'Bold (⌘B)',
          onTap: () => state._toggleInline(AppFlowyRichTextKeys.bold),
        ),
        _ToolbarButton(
          label: 'I',
          isItalic: true,
          active: state._isItalic,
          tooltip: 'Italic (⌘I)',
          onTap: () => state._toggleInline(AppFlowyRichTextKeys.italic),
        ),
        _ToolbarButton(
          label: 'U',
          isUnderline: true,
          active: state._isUnderline,
          tooltip: 'Underline (⌘U)',
          onTap: () => state._toggleInline(AppFlowyRichTextKeys.underline),
        ),
        _ToolbarButton(
          label: 'S',
          isStrikethrough: true,
          active: state._isStrikethrough,
          tooltip: 'Strikethrough',
          onTap: () => state._toggleInline(AppFlowyRichTextKeys.strikethrough),
        ),
        const _ToolbarDivider(),
        _ToolbarButton(
          label: 'Title',
          active: state._activeHeadingLevel == 1,
          tooltip: 'Title',
          onTap: () => state._toggleHeading(1),
        ),
        _ToolbarButton(
          label: 'Heading',
          active: state._activeHeadingLevel == 2,
          tooltip: 'Heading',
          onTap: () => state._toggleHeading(2),
        ),
        _ToolbarButton(
          label: 'Subheading',
          active: state._activeHeadingLevel == 3,
          tooltip: 'Subheading',
          onTap: () => state._toggleHeading(3),
        ),
        const _ToolbarDivider(),
        _ToolbarButton(
          icon: Icons.check_box_outlined,
          active: state._activeBlockType == TodoListBlockKeys.type,
          tooltip: 'Checkbox',
          onTap: () => state._toggleBlock(TodoListBlockKeys.type, {TodoListBlockKeys.checked: false}),
        ),
        _ToolbarButton(
          icon: Icons.format_list_bulleted,
          active: state._activeBlockType == BulletedListBlockKeys.type,
          tooltip: 'Bullet List',
          onTap: () => state._toggleBlock(BulletedListBlockKeys.type),
        ),
        _ToolbarButton(
          icon: Icons.format_list_numbered,
          active: state._activeBlockType == NumberedListBlockKeys.type,
          tooltip: 'Numbered List',
          onTap: () => state._toggleBlock(NumberedListBlockKeys.type),
        ),
      ]),
    );
    if (embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: row,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.surface(context),
        border: Border(top: BorderSide(color: AppSurfaces.divider(context))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: row,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool active;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    this.icon,
    this.label,
    this.active = false,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    TextDecoration? textDecoration;
    if (isUnderline) textDecoration = TextDecoration.underline;
    if (isStrikethrough) textDecoration = TextDecoration.lineThrough;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 30, minHeight: 28),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(
                    icon,
                    size: 18,
                    color: active ? AppColors.accent : (isDark ? Colors.white70 : Colors.black54),
                  )
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                      decoration: textDecoration,
                      color: active ? AppColors.accent : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppSurfaces.divider(context),
    );
  }
}
