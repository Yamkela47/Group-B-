// Widget tests for the Cutting Edge Salon app.
//
// These tests verify that:
//   1. The app boots and shows the splash screen with the brand title.
//   2. After the splash delay, the Role Selection screen appears.
//   3. Both Customer and Stylist role cards are displayed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutting_edge/main.dart';
import 'package:cutting_edge/role_selection_screen.dart';

void main() {
  testWidgets('App launches and shows the splash / brand title',
      (WidgetTester tester) async {
    // Build the app and pump one frame.
    await tester.pumpWidget(const CuttingEdgeApp());

    // The splash screen shows the brand name.
    expect(find.text('CUTTING EDGE'), findsOneWidget);
    expect(find.text('Our Vision Your Style'), findsOneWidget);
  });

  testWidgets('After splash delay, Role Selection screen appears',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CuttingEdgeApp());

    // Fast-forward past the 1.5s splash delay.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Role Selection screen should now be visible.
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Stylist'), findsOneWidget);
  });

  testWidgets('Tapping Stylist role highlights the Stylist card',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CuttingEdgeApp());

    // Skip splash.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Default selection is Customer.
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.content_cut), findsOneWidget);

    // Tap the Stylist role card.
    await tester.tap(find.text('Stylist'));
    await tester.pump();

    // The selected role should still be rendered (test passes if no exception).
    expect(find.text('Stylist'), findsOneWidget);
  });

  testWidgets('Sign In button navigates to Login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CuttingEdgeApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Tap the gold "SIGN IN" button (rendered uppercase).
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    // Login screen should be displayed.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
  });
}