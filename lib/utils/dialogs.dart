import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../database/database.dart';
import '../theme.dart';

class MoveToFolderResult {
  final bool confirmed;
  final Folder? folder;

  const MoveToFolderResult({required this.confirmed, this.folder});
}

/// The small grab handle shown at the top of modal bottom sheets.
class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.handle,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
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

  /// Shows a bottom sheet with a list of folders to choose from.
  static Future<MoveToFolderResult?> showFolderSelectionSheet({
    required BuildContext context,
    required List<Folder> folders,
    Folder? initialFolder,
  }) {
    return showModalBottomSheet<MoveToFolderResult>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MoveToFolderSheet(
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

class _MoveToFolderSheet extends StatelessWidget {
  final List<Folder> folders;
  final Folder? initialFolder;

  const _MoveToFolderSheet({
    required this.folders,
    this.initialFolder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomSheetHandle(),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Move to Folder',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTextColors.primary(context),
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              CupertinoIcons.folder,
              color: initialFolder == null ? AppColors.accent : AppTextColors.tertiary(context),
            ),
            title: const Text('No Folder (Root)'),
            trailing: initialFolder == null
                ? const Icon(CupertinoIcons.checkmark, color: AppColors.accent)
                : null,
            onTap: () => Navigator.pop(context, const MoveToFolderResult(confirmed: true)),
          ),
          const Divider(height: 1),
          ...folders.map((f) => ListTile(
                leading: Icon(
                  CupertinoIcons.folder_fill,
                  color: f.id == initialFolder?.id ? AppColors.accent : AppTextColors.tertiary(context),
                ),
                title: Text(f.name),
                trailing: f.id == initialFolder?.id
                    ? const Icon(CupertinoIcons.checkmark, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(
                  context,
                  MoveToFolderResult(confirmed: true, folder: f),
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
