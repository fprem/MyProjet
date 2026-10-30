import 'package:flutter/material.dart';

import '../ui/brand.dart';

/// Asks for the fingerprint, face or device PIN. True when the person passed.
typedef Authenticate = Future<bool> Function();

/// Keeps the archive behind the phone's own lock: when the app opens, and
/// again when it comes back after [lockAfter] in the background.
///
/// The app stays alive underneath, hidden, so a short trip to the camera or
/// a lock in the middle of adding a medicine loses nothing.
class AppLock extends StatefulWidget {
  const AppLock({
    super.key,
    required this.authenticate,
    required this.child,
    this.lockAfter = const Duration(seconds: 30),
    this.now = DateTime.now,
  });

  final Authenticate authenticate;
  final Widget child;
  final Duration lockAfter;
  final DateTime Function() now;

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _locked = true;
  bool _asking = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // The fingerprint prompt only makes the app inactive, never paused.
        _leftAt ??= widget.now();
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        if (leftAt != null && widget.now().difference(leftAt) >= widget.lockAfter) {
          setState(() => _locked = true);
        }
        if (_locked) _unlock();
      default:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    bool passed;
    try {
      passed = await widget.authenticate();
    } catch (_) {
      passed = false;
    } finally {
      _asking = false;
    }
    if (mounted && passed) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Offstage(
          offstage: _locked,
          child: TickerMode(enabled: !_locked, child: widget.child),
        ),
        if (_locked) _LockedScreen(onUnlock: _unlock),
      ],
    );
  }
}

class _LockedScreen extends StatelessWidget {
  const _LockedScreen({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 20,
              children: [
                const LogoMark(size: 88),
                Text(
                  'Medicine Archive is locked',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  'Use your fingerprint, face or phone PIN to open it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                FilledButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
