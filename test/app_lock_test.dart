import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note/services/app_lock_service.dart';
import 'package:note/widgets/app_lock_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppLockService extends AppLockService {
  _FakeAppLockService({
    required this.canAuth,
    required this.authResult,
    super.gracePeriod,
    super.clock,
  });

  final bool canAuth;
  bool authResult;
  int authenticateCalls = 0;

  @override
  Future<bool> canAuthenticate() async => canAuth;

  @override
  Future<bool> authenticate({String reason = 'Unlock your notes'}) async {
    authenticateCalls++;
    if (authResult) {
      await markUnlocked();
    }
    return authResult;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppLockService grace period expires after configured duration', () async {
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final service = AppLockService(
      gracePeriod: const Duration(minutes: 5),
      clock: () => now,
    );

    expect(await service.isWithinGracePeriod(), isFalse);

    await service.markUnlocked();
    expect(await service.isWithinGracePeriod(), isTrue);

    now = now.add(const Duration(minutes: 4, seconds: 59));
    expect(await service.isWithinGracePeriod(), isTrue);

    now = now.add(const Duration(seconds: 1));
    expect(await service.isWithinGracePeriod(), isFalse);
  });

  testWidgets('AppLockGate skips prompt on startup when within grace period',
      (tester) async {
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final service = _FakeAppLockService(
      canAuth: true,
      authResult: true,
      gracePeriod: const Duration(minutes: 5),
      clock: () => now,
    );
    await service.markUnlocked();
    now = now.add(const Duration(minutes: 2));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          service: service,
          child: const Text('Unlocked Content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 0);
    expect(find.text('Unlocked Content'), findsOneWidget);
  });

  testWidgets('AppLockGate prompts on startup when grace period expired, then caches on pause/resume',
      (tester) async {
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final service = _FakeAppLockService(
      canAuth: true,
      authResult: true,
      gracePeriod: const Duration(minutes: 5),
      clock: () => now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          service: service,
          child: const Text('Unlocked Content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 1);
    expect(find.text('Unlocked Content'), findsOneWidget);

    // Brief background switch (1 minute) -> should NOT re-prompt.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.add(const Duration(minutes: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 1);
    expect(find.text('Unlocked Content'), findsOneWidget);

    // Long background switch (6 minutes) -> SHOULD re-prompt.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.add(const Duration(minutes: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 2);
    expect(find.text('Unlocked Content'), findsOneWidget);
  });
}
