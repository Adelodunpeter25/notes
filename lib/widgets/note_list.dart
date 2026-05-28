import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

class NoteListPane extends StatelessWidget {
  const NoteListPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CupertinoSearchTextField(
            placeholder: 'Search notes',
            style: MacosTheme.of(context).typography.body,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 5, // Placeholder
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: MacosListTile(
                  title: Text(
                    'Sample Note $index',
                    style: MacosTheme.of(context).typography.headline,
                  ),
                  subtitle: Text(
                    'This is a snippet of the note content...',
                    style: MacosTheme.of(context).typography.subheadline,
                  ),
                  onClick: () {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
