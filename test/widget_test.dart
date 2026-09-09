import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_my_life/main.dart';

void main() {
  testWidgets('FollowMyLifeApp smoke test', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: FollowMyLifeApp(),
        ),
      );
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
