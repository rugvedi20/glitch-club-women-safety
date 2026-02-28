import 'package:flutter/material.dart';
import 'package:safety_pal/theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════════════════
// SAFETY PAL — Shared UI Components
// ════════════════════════════════════════════════════════════════════════════

/// Premium elevated card with consistent styling
class SPCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BoxDecoration? decoration;

  const SPCard({
    required this.child,
    this.padding,
    this.onTap,
    this.decoration,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppTheme.spacingLG),
        decoration: decoration ?? AppTheme.cardDecoration,
        child: child,
      ),
    );
  }
}

/// Primary gradient button — full width
class SPPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const SPPrimaryButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: onPressed != null && !isLoading
              ? AppTheme.primaryGradient
              : null,
          color: onPressed == null || isLoading ? AppTheme.divider : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: onPressed != null && !isLoading
              ? [
                  BoxShadow(
                    color: AppTheme.primaryRed.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(text, style: AppTheme.buttonText),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Outlined button with consistent styling
class SPOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const SPOutlinedButton({
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryRed;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.withOpacity(0.3), width: 1.5),
          color: c.withOpacity(0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: c, size: 18),
              const SizedBox(width: 8),
            ],
            Text(text, style: AppTheme.labelLarge.copyWith(color: c)),
          ],
        ),
      ),
    );
  }
}

/// Section header with optional action
class SPSectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const SPSectionHeader({
    required this.title,
    this.actionText,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTheme.headlineMedium),
          if (actionText != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: AppTheme.labelMedium.copyWith(color: AppTheme.primaryRed),
              ),
            ),
        ],
      ),
    );
  }
}

/// Skeleton loading placeholder
class SPSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SPSkeleton({
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
    super.key,
  });

  @override
  State<SPSkeleton> createState() => _SPSkeletonState();
}

class _SPSkeletonState extends State<SPSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * _controller.value, 0),
              end: Alignment(-1.0 + 2 * _controller.value + 1, 0),
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF5F5F5),
                Color(0xFFEEEEEE),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// AnimatedBuilder wrapper (shimmer effect)
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    required this.animation,
    required this.builder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(listenable: animation, builder: builder);
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder2({
    required super.listenable,
    required this.builder,
    super.key,
  }) : super();

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}

/// Empty state widget
class SPEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonTap;

  const SPEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing3XL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Text(title, style: AppTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingSM),
            Text(subtitle, style: AppTheme.bodyMedium, textAlign: TextAlign.center),
            if (buttonText != null) ...[
              const SizedBox(height: AppTheme.spacingXL),
              SPOutlinedButton(text: buttonText!, onPressed: onButtonTap),
            ],
          ],
        ),
      ),
    );
  }
}

/// Blurred modal bottom sheet helper
Future<T?> showSPBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          builder(context),
        ],
      ),
    ),
  );
}

/// Permission dialog with blurred background
class SPPermissionDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const SPPermissionDialog({
    required this.icon,
    required this.title,
    required this.description,
    required this.onAllow,
    required this.onDeny,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.coralLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppTheme.primaryRed),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(title, style: AppTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingSM),
            Text(description, style: AppTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingXXL),
            SPPrimaryButton(text: 'Allow', onPressed: onAllow),
            const SizedBox(height: AppTheme.spacingSM),
            TextButton(
              onPressed: onDeny,
              child: Text(
                'Not Now',
                style: AppTheme.labelLarge.copyWith(color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
