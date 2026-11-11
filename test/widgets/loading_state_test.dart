import 'package:flutter/material.dart';
import 'package:flutter_agentify/core/widgets/states/loading_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoadingState', () {
    testWidgets('renders CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingState())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders message when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingState(message: 'Loading data...')),
        ),
      );

      expect(find.text('Loading data...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not render message text when message is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingState())),
      );

      // Only the progress indicator, no extra text widgets from LoadingState
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
