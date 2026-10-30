import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/security/app_lock.dart';

void main() {
  late List<bool> answers;
  late int asked;
  late DateTime clock;

  Future<bool> authenticate() async {
    asked++;
    return answers.isEmpty ? false : answers.removeAt(0);
  }

  setUp(() {
    answers = [];
    asked = 0;
    clock = DateTime(2026, 10, 30, 9);
  });

  Future<void> pumpLock(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLock(
          authenticate: authenticate,
          now: () => clock,
          child: const Scaffold(body: Text('Anna: Aspirina')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> background(WidgetTester tester, Duration away) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    clock = clock.add(away);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('asks for the fingerprint or PIN when the app opens', (tester) async {
    answers = [true];
    await pumpLock(tester);

    expect(asked, 1);
    expect(find.text('Anna: Aspirina'), findsOneWidget);
    expect(find.text('Medicine Archive is locked'), findsNothing);
  });

  testWidgets('stays locked and hides everything until unlocked', (tester) async {
    answers = [false];
    await pumpLock(tester);

    expect(find.text('Medicine Archive is locked'), findsOneWidget);
    expect(find.text('Anna: Aspirina'), findsNothing);

    answers = [true];
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(asked, 2);
    expect(find.text('Anna: Aspirina'), findsOneWidget);
  });

  testWidgets('locks again after a while in the background', (tester) async {
    answers = [true, false];
    await pumpLock(tester);

    await background(tester, const Duration(minutes: 5));

    expect(asked, 2);
    expect(find.text('Medicine Archive is locked'), findsOneWidget);
    expect(find.text('Anna: Aspirina'), findsNothing);
  });

  testWidgets('a quick trip to the camera does not lock', (tester) async {
    answers = [true];
    await pumpLock(tester);

    await background(tester, const Duration(seconds: 10));

    expect(asked, 1);
    expect(find.text('Anna: Aspirina'), findsOneWidget);
  });

  testWidgets('keeps the screen underneath, so work in progress is not lost', (tester) async {
    answers = [true, true];
    await pumpLock(tester);
    final before = tester.state(find.byType(Scaffold));

    await background(tester, const Duration(minutes: 5));

    expect(tester.state(find.byType(Scaffold)), same(before));
  });
}
