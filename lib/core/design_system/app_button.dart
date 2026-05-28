import 'package:flutter/material.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';

class AppPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final Color? backgroundColor;

  const AppPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isFullWidth = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
        ),
      ),
      onPressed: onPressed,
      child: buttonContent,
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final Color? foregroundColor;

  const AppSecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isFullWidth = true,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor ?? Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        side: BorderSide(color: foregroundColor ?? Theme.of(context).colorScheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
        ),
      ),
      onPressed: onPressed,
      child: buttonContent,
    );
  }
}
