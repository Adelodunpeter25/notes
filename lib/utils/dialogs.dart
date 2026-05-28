import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../database/database.dart';

class MoveToFolderResult {
  final bool confirmed;
  final Folder? folder;

  const MoveToFolderResult({required this.confirmed, this.folder});
}

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

  /// Shows a macOS dialog containing a dropdown of folders to choose from
  static Future<MoveToFolderResult?> showFolderSelectionDialog({
    required BuildContext context,
    required List<Folder> folders,
    Folder? initialFolder,
  }) async {
    return showMacosAlertDialog<MoveToFolderResult>(
      context: context,
      builder: (context) => _MoveToFolderDialog(
        folders: folders,
        initialFolder: initialFolder,
      ),
    );
  }
}

class _MoveToFolderDialog extends StatefulWidget {
  final List<Folder> folders;
  final Folder? initialFolder;

  const _MoveToFolderDialog({
    required this.folders,
    this.initialFolder,
  });

  @override
  State<_MoveToFolderDialog> createState() => _MoveToFolderDialogState();
}

class _MoveToFolderDialogState extends State<_MoveToFolderDialog> {
  Folder? _selectedFolder;
  bool _useNoFolder = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFolder == null) {
      _useNoFolder = true;
    } else {
      _selectedFolder = widget.initialFolder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownItems = [
      const MacosPopupMenuItem<Folder?>(
        value: null,
        child: Text('No Folder (Root)'),
      ),
      ...widget.folders.map((f) => MacosPopupMenuItem<Folder?>(
            value: f,
            child: Text(f.name),
          )),
    ];

    return MacosAlertDialog(
      appIcon: const MacosIcon(CupertinoIcons.folder),
      title: const Text('Move to Folder'),
      message: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Choose a destination folder for this note:'),
            const SizedBox(height: 16),
            MacosPopupButton<Folder?>(
              value: _useNoFolder ? null : _selectedFolder,
              items: dropdownItems,
              onChanged: (Folder? value) {
                setState(() {
                  if (value == null) {
                    _useNoFolder = true;
                    _selectedFolder = null;
                  } else {
                    _useNoFolder = false;
                    _selectedFolder = value;
                  }
                });
              },
            ),
          ],
        ),
      ),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () {
          Navigator.pop(
            context,
            MoveToFolderResult(
              confirmed: true,
              folder: _useNoFolder ? null : _selectedFolder,
            ),
          );
        },
        child: const Text('Move'),
      ),
      secondaryButton: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        onPressed: () => Navigator.pop(context, const MoveToFolderResult(confirmed: false)),
        child: const Text('Cancel'),
      ),
    );
  }
}
