import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/core/services/biometric_service.dart';
import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';

class LockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with WidgetsBindingObserver {
  bool _authenticating = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() { _authenticating = true; _failed = false; });
    final success = await BiometricService.authenticate();
    if (mounted) {
      setState(() { _authenticating = false; });
      if (success) {
        widget.onUnlocked();
      } else {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 50),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'Control Financiero',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Verifica tu identidad para continuar',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl * 2),

                if (_authenticating)
                  const CircularProgressIndicator(color: Colors.white)
                else ...[
                  if (_failed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dangerLight.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Verificación fallida. Intenta nuevamente.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  GestureDetector(
                    onTap: _authenticate,
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38, width: 2),
                          ),
                          child: const Icon(Icons.fingerprint, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Toca para autenticar',
                          style: AppTextStyles.label.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
