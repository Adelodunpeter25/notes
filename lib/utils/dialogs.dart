import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../database/database.dart';

class MoveToFolderResult {
  final bool confirmed;
  final Folder? folder;

  const MoveToFolderResult({required this.confirmed, this.folder});
}

class DialogUtils {
  /// Shows a confirmation dialog
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String primaryButtonText = 'OK',
    String secondaryButtonText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(CupertinoIcons.question_circle),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(secondaryButtonText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              primaryButtonText,
              style: isDestructive ? const TextStyle(color: CupertinoColors.destructiveRed) : null,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a dialog containing a dropdown of folders to choose from
  static Future<MoveToFolderResult?> showFolderSelectionDialog({
    required BuildContext context,
    required List<Folder> folders,
    Folder? initialFolder,
  }) async {
    return showDialog<MoveToFolderResult>(
      context: context,
      builder: (context) => _MoveToFolderDialog(
        folders: folders,
        initialFolder: initialFolder,
      ),
    );
  }

  /// Shows a dialog containing a text field for entering text (e.g. folder name)
  static Future<String?> showTextInputDialog({
    required BuildContext context,
    required String title,
    required String placeholder,
    String primaryButtonText = 'OK',
    String secondaryButtonText = 'Cancel',
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(CupertinoIcons.folder_badge_plus),
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: placeholder,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(secondaryButtonText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(primaryButtonText),
          ),
        ],
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
      const DropdownMenuItem<Folder?>(
        value: null,
        child: Text('No Folder (Root)'),
      ),
      ...widget.folders.map((f) => DropdownMenuItem<Folder?>(
            value: f,
            child: Text(f.name),
          )),
    ];

    return AlertDialog(
      icon: const Icon(CupertinoIcons.folder),
      title: const Text('Move to Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Choose a destination folder for this note:'),
          const SizedBox(height: 16),
          DropdownButton<Folder?>(
            value: _useNoFolder ? null : _selectedFolder,
            items: dropdownItems,
            isExpanded: true,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const MoveToFolderResult(confirmed: false)),
          child: const Text('Cancel'),
        ),
        TextButton(
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
      ],
    );
  }
}
