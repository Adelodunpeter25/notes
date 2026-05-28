import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MenuAnchor, MenuController, MenuStyle, WidgetStateProperty;
import 'package:macos_ui/macos_ui.dart';

class EditorFormattingToolbar extends StatefulWidget {
  final EditorState editorState;
  final bool isPinned;
  final VoidCallback onPinToggle;
  final VoidCallback onToggleChecklist;

  const EditorFormattingToolbar({
    super.key,
    required this.editorState,
    required this.isPinned,
    required this.onPinToggle,
    required this.onToggleChecklist,
  });

  @override
  State<EditorFormattingToolbar> createState() => _EditorFormattingToolbarState();
}

class _EditorFormattingToolbarState extends State<EditorFormattingToolbar> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          // Left side: Aa dropdown and Checklist
          MenuAnchor(
            controller: _menuController,
            style: MenuStyle(
              backgroundColor: WidgetStateProperty.all(MacosTheme.of(context).canvasColor),
              elevation: WidgetStateProperty.all(8.0),
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: MacosTheme.of(context).dividerColor, width: 0.5),
                ),
              ),
            ),
            builder: (context, controller, child) {
              return MacosIconButton(
                icon: const Text(
                  'Aa',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
            menuChildren: [
              AaDropdownContent(
                editorState: widget.editorState,
                onClose: () {
                  _menuController.close();
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.square_list, size: 18),
            onPressed: widget.onToggleChecklist,
          ),
          const Spacer(),

          // Right side: Search, separator, pin
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.search, size: 18),
            onPressed: () {},
          ),
          Container(
            width: 1,
            height: 18,
            color: MacosTheme.of(context).dividerColor,
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
          ),
          MacosIconButton(
            icon: MacosIcon(
              widget.isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
              size: 18,
              color: widget.isPinned ? MacosTheme.of(context).primaryColor : null,
            ),
            onPressed: widget.onPinToggle,
          ),
        ],
      ),
    );
  }
}


class AaDropdownContent extends StatefulWidget {
  final EditorState editorState;
  final VoidCallback onClose;

  const AaDropdownContent({
    super.key,
    required this.editorState,
    required this.onClose,
  });

  @override
  State<AaDropdownContent> createState() => _AaDropdownContentState();
}

class _AaDropdownContentState extends State<AaDropdownContent> {
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
    if (mounted) {
      setState(() {
        _updateState();
      });
    }
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
      if (node.type == HeadingBlockKeys.type) {
        _activeHeadingLevel = node.attributes[HeadingBlockKeys.level] as int? ?? 0;
      } else {
        _activeHeadingLevel = 0;
      }
    }
  }

  void _toggleInline(String key) {
    widget.editorState.toggleAttribute(key);
    _updateState();
    setState(() {});
  }

  void _toggleBlock(String blockType, [Map<String, dynamic>? attributes]) {
    final selection = widget.editorState.selection;
    if (selection == null) return;

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final isAlreadyType = node.type == blockType &&
        (attributes == null || node.attributes[HeadingBlockKeys.level] == attributes[HeadingBlockKeys.level]);

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
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = MacosTheme.of(context).dividerColor;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InlineButton(
                label: 'B',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                isActive: _isBold,
                onTap: () => _toggleInline(AppFlowyRichTextKeys.bold),
              ),
              _InlineButton(
                label: 'I',
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15),
                isActive: _isItalic,
                onTap: () => _toggleInline(AppFlowyRichTextKeys.italic),
              ),
              _InlineButton(
                label: 'U',
                style: const TextStyle(decoration: TextDecoration.underline, fontSize: 15),
                isActive: _isUnderline,
                onTap: () => _toggleInline(AppFlowyRichTextKeys.underline),
              ),
              _InlineButton(
                label: 'S',
                style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 15),
                isActive: _isStrikethrough,
                onTap: () => _toggleInline(AppFlowyRichTextKeys.strikethrough),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 0.5, color: dividerColor),
          const SizedBox(height: 6),
          _BlockStyleItem(
            label: 'Title',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            isActive: _activeBlockType == HeadingBlockKeys.type && _activeHeadingLevel == 1,
            onTap: () => _toggleBlock(HeadingBlockKeys.type, {HeadingBlockKeys.level: 1}),
          ),
          _BlockStyleItem(
            label: 'Heading',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            isActive: _activeBlockType == HeadingBlockKeys.type && _activeHeadingLevel == 2,
            onTap: () => _toggleBlock(HeadingBlockKeys.type, {HeadingBlockKeys.level: 2}),
          ),
          _BlockStyleItem(
            label: 'Subheading',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            isActive: _activeBlockType == HeadingBlockKeys.type && _activeHeadingLevel == 3,
            onTap: () => _toggleBlock(HeadingBlockKeys.type, {HeadingBlockKeys.level: 3}),
          ),
          _BlockStyleItem(
            label: 'Body',
            style: const TextStyle(fontSize: 13),
            isActive: _activeBlockType == ParagraphBlockKeys.type,
            onTap: () => _toggleBlock(ParagraphBlockKeys.type),
          ),
          _BlockStyleItem(
            label: 'Monospaced',
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            isActive: _activeBlockType == 'code_block',
            onTap: () => _toggleBlock('code_block'),
          ),
          _BlockStyleItem(
            label: 'Bulleted List',
            style: const TextStyle(fontSize: 13),
            isActive: _activeBlockType == 'bulleted_list',
            onTap: () => _toggleBlock('bulleted_list'),
          ),
          _BlockStyleItem(
            label: 'Dashed List',
            style: const TextStyle(fontSize: 13),
            isActive: _activeBlockType == 'dashed_list',
            onTap: () => _toggleBlock('bulleted_list'),
          ),
          _BlockStyleItem(
            label: 'Numbered List',
            style: const TextStyle(fontSize: 13),
            isActive: _activeBlockType == 'numbered_list',
            onTap: () => _toggleBlock('numbered_list'),
          ),
        ],
      ),
    );
  }
}

class _InlineButton extends StatefulWidget {
  final String label;
  final TextStyle style;
  final bool isActive;
  final VoidCallback onTap;

  const _InlineButton({
    required this.label,
    required this.style,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_InlineButton> createState() => _InlineButtonState();
}

class _InlineButtonState extends State<_InlineButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeBg = MacosTheme.of(context).primaryColor;
    const activeFg = CupertinoColors.white;
    final hoverBg = CupertinoColors.systemGrey5.withOpacity(0.3);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.isActive 
                ? activeBg 
                : (_isHovered ? hoverBg : CupertinoColors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: widget.style.copyWith(
              color: widget.isActive ? activeFg : MacosTheme.of(context).typography.body.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockStyleItem extends StatefulWidget {
  final String label;
  final TextStyle style;
  final bool isActive;
  final VoidCallback onTap;

  const _BlockStyleItem({
    required this.label,
    required this.style,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_BlockStyleItem> createState() => _BlockStyleItemState();
}

class _BlockStyleItemState extends State<_BlockStyleItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = CupertinoColors.systemGrey5.withOpacity(0.3);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: _isHovered ? hoverBg : CupertinoColors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: widget.isActive
                    ? const Icon(
                        CupertinoIcons.check_mark,
                        size: 13,
                        color: CupertinoColors.systemGrey2,
                      )
                    : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.label,
                  style: widget.style.copyWith(
                    color: MacosTheme.of(context).typography.body.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
