import 'package:flutter/material.dart';

/// Central bottom-sheet component used across the app.
///
/// Wraps [child] in a [SafeArea] + [Column] with the standard grab handle.
/// Use [AppBottomSheet.show] to present it as a modal bottom sheet with the
/// app's consistent rounded-top shape.
class AppBottomSheet extends StatelessWidget {
  final Widget child;

  const AppBottomSheet({super.key, required this.child});

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  );

  /// Shows a modal bottom sheet with the standard shape and grab handle.
  ///
  /// [builder] should return the sheet content. The [AppBottomSheet] wrapper
  /// (grab handle + SafeArea) is applied automatically.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext context) builder,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      shape: _shape,
      builder: (context) => AppBottomSheet(child: builder(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GrabHandle(),
          child,
        ],
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white24
            : Colors.black26,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
