import 'package:flutter/material.dart';
import 'package:flutter_agentify/core/widgets/states/error_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorState', () {
    testWidgets('renders message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorState(message: 'Something went wrong')),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders error icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorState(message: 'Error occurred')),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('does not render retry button when onRetry is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorState(message: 'Simple error')),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
