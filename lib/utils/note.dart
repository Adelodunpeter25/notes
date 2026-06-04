import 'dart:convert';

/// Helpers for deriving a note title from its content.
///
/// The editor has no separate title field; the first non-empty line of the
/// document body becomes the title. If nothing can be extracted, falls back
/// to "Untitled".
class NoteUtils {
  /// Parse the stored content string and return plain text, line by line.
  ///
  /// Handles AppFlowy editor JSON (a tree of blocks, each with a `delta`
  /// containing insert ops) and degrades gracefully to raw text for any
  /// content that is not valid JSON.
  static List<String> extractLines(String content) {
    if (content.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        final lines = <String>[];
        final rootNode = decoded['document'] is Map<String, dynamic>
            ? decoded['document'] as Map<String, dynamic>
            : decoded;
        _collectLines(rootNode, lines);
        return lines;
      }
    } catch (_) {
      // Not JSON — treat the content itself as plain text.
    }
    return content.split('\n');
  }

  static void _collectLines(Map<String, dynamic> node, List<String> out) {
    final delta = node['delta'] ?? node['data']?['delta'] ?? node['attributes']?['delta'];
    if (delta is List) {
      final buf = StringBuffer();
      for (final op in delta) {
        if (op is Map && op['insert'] is String) {
          buf.write(op['insert'] as String);
        }
      }
      final text = buf.toString();
      // AppFlowy stores one block per line; split in case a delta contains \n.
      for (final line in text.split('\n')) {
        out.add(line);
      }
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _collectLines(child, out);
        }
      }
    }
  }

  /// Return the first non-empty line from the content, trimmed and clamped
  /// to [maxLength] characters. Suitable for use as a note title.
  static String titleFromContent(String content, {int maxLength = 80}) {
    for (final raw in extractLines(content)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.length <= maxLength) return line;
      return '${line.substring(0, maxLength).trimRight()}…';
    }
    return 'Untitled';
  }
}
