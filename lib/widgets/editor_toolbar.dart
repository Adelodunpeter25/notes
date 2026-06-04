import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// A mobile-optimized formatting toolbar that docks at the bottom of the editor
/// above the keyboard. Provides quick access to formatting options.
class EditorToolbar extends StatefulWidget {
  final EditorState editorState;
  final VoidCallback onToggleChecklist;

  const EditorToolbar({
    super.key,
    required this.editorState,
    required this.onToggleChecklist,
  });

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {
  bool _showFormattingOptions = false;
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
      setState(_updateState);
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
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: AppSurfaces.surface(context),
          border: Border(top: BorderSide(color: AppSurfaces.divider(context), width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expanded formatting area
              if (_showFormattingOptions) ...[
                _buildBlockStyleOptions(context),
                Divider(height: 1, color: AppSurfaces.divider(context)),
              ],

              // Main toolbar row
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    // Aa text style button
                    _ToolbarButton(
                      icon: null,
                      label: 'Aa',
                      isActive: _showFormattingOptions,
                      accentColor: AppColors.accent,
                      onTap: () {
                        setState(() => _showFormattingOptions = !_showFormattingOptions);
                      },
                    ),

                    // Separator
                    Container(width: 1, height: 24, color: AppSurfaces.divider(context)),

                    // Bold
                    _ToolbarButton(
                      icon: null,
                      label: 'B',
                      isActive: _isBold,
                      isBold: true,
                      accentColor: AppColors.accent,
                      onTap: () => _toggleInline(AppFlowyRichTextKeys.bold),
                    ),

                    // Italic
                    _ToolbarButton(
                      icon: null,
                      label: 'I',
                      isActive: _isItalic,
                      isItalic: true,
                      accentColor: AppColors.accent,
                      onTap: () => _toggleInline(AppFlowyRichTextKeys.italic),
                    ),

                    // Underline
                    _ToolbarButton(
                      icon: null,
                      label: 'U',
                      isActive: _isUnderline,
                      isUnderline: true,
                      accentColor: AppColors.accent,
                      onTap: () => _toggleInline(AppFlowyRichTextKeys.underline),
                    ),

                    // Strikethrough
                    _ToolbarButton(
                      icon: null,
                      label: 'S',
                      isActive: _isStrikethrough,
                      isStrikethrough: true,
                      accentColor: AppColors.accent,
                      onTap: () => _toggleInline(AppFlowyRichTextKeys.strikethrough),
                    ),

                    // Separator
                    Container(width: 1, height: 24, color: AppSurfaces.divider(context)),

                    // Checklist
                    _ToolbarButton(
                      icon: CupertinoIcons.checkmark_square,
                      isActive: _activeBlockType == 'todo_list',
                      accentColor: AppColors.accent,
                      onTap: widget.onToggleChecklist,
                    ),

                    // Bullet list
                    _ToolbarButton(
                      icon: CupertinoIcons.list_bullet,
                      isActive: _activeBlockType == 'bulleted_list',
                      accentColor: AppColors.accent,
                      onTap: () => _toggleBlock('bulleted_list'),
                    ),

                    // Numbered list
                    _ToolbarButton(
                      icon: CupertinoIcons.list_number,
                      isActive: _activeBlockType == 'numbered_list',
                      accentColor: AppColors.accent,
                      onTap: () => _toggleBlock('numbered_list'),
                    ),

                    const Spacer(),

                    // Dismiss keyboard
                    _ToolbarButton(
                      icon: CupertinoIcons.keyboard_chevron_compact_down,
                      accentColor: AppColors.accent,
                      onTap: () {
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockStyleOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _BlockChip(
            label: 'Title',
            isActive: _activeBlockType == HeadingBlockKeys.type && _activeHeadingLevel == 1,
            onTap: () => _toggleBlock(HeadingBlockKeys.type, {HeadingBlockKeys.level: 1}),
          ),
          _BlockChip(
            label: 'Heading',
            isActive: _activeBlockType == HeadingBlockKeys.type && _activeHeadingLevel == 2,
            onTap: () => _toggleBlock(HeadingBlockKeys.type, {HeadingBlockKeys.level: 2}),
          ),
          _BlockChip(
            label: 'Subheading',
            isActive: _activeBlockType == HeadingBlockKeys.type && _activeHeadingLevel == 3,
            onTap: () => _toggleBlock(HeadingBlockKeys.type, {HeadingBlockKeys.level: 3}),
          ),
          _BlockChip(
            label: 'Body',
            isActive: _activeBlockType == ParagraphBlockKeys.type,
            onTap: () => _toggleBlock(ParagraphBlockKeys.type),
          ),
          _BlockChip(
            label: 'Code',
            isActive: _activeBlockType == 'code_block',
            onTap: () => _toggleBlock('code_block'),
          ),
          _BlockChip(
            label: 'Quote',
            isActive: _activeBlockType == 'quote',
            onTap: () => _toggleBlock('quote'),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool isActive;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final Color accentColor;
  final VoidCallback onTap;

  const _ToolbarButton({
    this.icon,
    this.label,
    this.isActive = false,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    TextDecoration? textDecoration;
    if (isUnderline) textDecoration = TextDecoration.underline;
    if (isStrikethrough) textDecoration = TextDecoration.lineThrough;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? accentColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? accentColor
                      : (isDark ? Colors.white70 : Colors.black54),
                )
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                    decoration: textDecoration,
                    color: isActive
                        ? accentColor
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
        ),
      ),
    );
  }
}

class _BlockChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BlockChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.accent.withOpacity(0.2)
          : AppSurfaces.elevated(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? AppColors.accent
                  : AppTextColors.primary(context).withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}
