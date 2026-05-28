import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

class DialogUtils {
  /// Shows a native macOS confirmation dialog (Electron-style)
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String primaryButtonText = 'OK',
    String secondaryButtonText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showMacosAlertDialog<bool>(
      context: context,
      builder: (context) => MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.question_circle),
        title: Text(title),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: !isDestructive,
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            primaryButtonText,
            style: isDestructive ? const TextStyle(color: CupertinoColors.destructiveRed) : null,
          ),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () => Navigator.pop(context, false),
          child: Text(secondaryButtonText),
        ),
      ),
    );
    return result ?? false;
  }
}
