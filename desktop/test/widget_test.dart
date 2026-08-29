import 'package:desktop/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots and renders the shell', (WidgetTester tester) async {
    await tester.pumpWidget(const NoteDesktopApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

