import 'dart:convert';

import 'package:desktop/core/utils/note_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteUtils.extractLines', () {
    test('returns empty list for empty content', () {
      expect(NoteUtils.extractLines(''), isEmpty);
      expect(NoteUtils.extractLines('   '), isEmpty);
    });

    test('parses AppFlowy document JSON into lines', () {
      final doc = jsonEncode({
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'heading',
              'delta': [
                {'insert': 'Groceries'},
              ],
            },
            {
              'type': 'todo-list',
              'delta': [
                {'insert': 'Buy apples'},
              ],
            },
          ],
        },
      });

      expect(NoteUtils.extractLines(doc), ['Groceries', 'Buy apples']);
    });

    test('falls back to raw text when content is not JSON', () {
      expect(NoteUtils.extractLines('plain\nlines'), ['plain', 'lines']);
    });

    test('isContentEmpty detects empty JSON documents', () {
      final doc = jsonEncode({
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'paragraph',
              'delta': [
                {'insert': '   '},
              ],
            },
          ],
        },
      });
      expect(NoteUtils.isContentEmpty(doc), isTrue);
      expect(NoteUtils.isContentEmpty(''), isTrue);
      expect(NoteUtils.isContentEmpty('hello'), isFalse);
    });
  });

  group('NoteUtils.titleFromContent', () {
    test('returns first non-empty line', () {
      final doc = jsonEncode({
        'document': {
          'children': [
            {'delta': []},
            {
              'delta': [
                {'insert': 'Real Title'},
              ],
            },
          ],
        },
      });
      expect(NoteUtils.titleFromContent(doc), 'Real Title');
    });

    test('falls back to Untitled', () {
      expect(NoteUtils.titleFromContent(''), 'Untitled');
    });

    test('clamps long titles with ellipsis', () {
      final long = 'a' * 100;
      final title = NoteUtils.titleFromContent(long);
      expect(title.length, 81); // 80 chars + ellipsis
      expect(title.endsWith('…'), isTrue);
    });
  });
}
