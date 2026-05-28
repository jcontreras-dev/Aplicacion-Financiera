import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/core/theme/app_theme.dart';
import 'package:finance_app/core/router/app_router.dart';
import 'package:finance_app/core/providers/theme_provider.dart';
import 'package:finance_app/core/services/biometric_service.dart';
import 'package:finance_app/core/services/notification_service.dart';
import 'package:finance_app/features/auth/presentation/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(
    const ProviderScope(
      child: FinanceApp(),
    ),
  );
}

class FinanceApp extends ConsumerWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return AuthGate(
      child: MaterialApp.router(
        title: 'Control de Finanzas',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: goRouter,
      ),
    );
  }
}

// Widget raíz que gestiona la pantalla de bloqueo biométrico
class AuthGate extends ConsumerStatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _biometricsEnabled = false;
  DateTime? _backgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await BiometricService.isEnabled();
    final available = await BiometricService.isAvailable();
    if (mounted) {
      setState(() {
        _biometricsEnabled = enabled && available;
        _locked = _biometricsEnabled;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_biometricsEnabled) return;
    if (state == AppLifecycleState.paused) {
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundTime;
      if (bg != null && DateTime.now().difference(bg).inSeconds > 60) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return LockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return widget.child;
  }
}
