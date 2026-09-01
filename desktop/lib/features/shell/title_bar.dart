import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/theme.dart';
import '../editor/editor_toolbar.dart';

/// Apple Notes–style title bar that hosts the editor toolbar.
///
/// When [editorState] is non-null the formatting toolbar is centered in the
/// title bar (draggable area kept). When null, shows a placeholder so the
/// bar still feels balanced. The bar is 52pt tall to match macOS design and
/// reserves ~72pt on the left for the traffic lights.
class ShellTitleBar extends StatelessWidget {
  final EditorState? editorState;
  final String viewTitle;

  const ShellTitleBar({
    super.key,
    required this.editorState,
    required this.viewTitle,
  });

  @override
  Widget build(BuildContext context) {
    // Use DragToMoveArea so the user can drag the window by the title bar
    // (window_manager). On platforms where the plugin isn't initialized this
    // is just a visual container.
    final bar = Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppSurfaces.surface(context),
        border: Border(
          bottom: BorderSide(color: AppSurfaces.divider(context)),
        ),
      ),
      child: Row(
        children: [
          // Traffic-light safe area on macOS (empty but keeps toolbar centered).
          const SizedBox(width: 72),
          // Left: view title (optional, muted) — mirrors Apple Notes' folder name
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                viewTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTextColors.secondary(context),
                ),
              ),
            ),
          ),
          // Center: toolbar when a note is selected, else a subtle hint.
          Expanded(
            flex: 5,
            child: Center(
              child: editorState == null
                  ? Text(
                      'No Note Selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTextColors.tertiary(context),
                      ),
                    )
                  : _TitleBarToolbar(editorState: editorState!),
            ),
          ),
          // Right: spacer to balance the layout; could hold window buttons.
          const Expanded(flex: 2, child: SizedBox.shrink()),
        ],
      ),
    );

    // window_manager's DragToMoveArea requires the window to be initialized;
    // gracefully degrade if not available (e.g. in widget tests).
    try {
      return DragToMoveArea(child: bar);
    } catch (_) {
      return bar;
    }
  }
}

/// Compact toolbar variant for the title bar. Reuses the same block/inline
/// logic as [DesktopEditorToolbar] but with tighter padding so it fits in
/// 52pt and doesn't cause a RenderFlex overflow on narrow windows.
class _TitleBarToolbar extends StatelessWidget {
  final EditorState editorState;

  const _TitleBarToolbar({required this.editorState});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: DesktopEditorToolbar(editorState: editorState, embedded: true),
    );
  }
}
