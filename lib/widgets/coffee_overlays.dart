import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand_mark.dart';

class CoffeeColors {
  static const ink = BrandMark.espresso;
  static const cream = BrandMark.cream;
  static const border = Color(0xFFE8DED3);
  static const muted = Color(0xFF806B5B);
  static const success = Color(0xFF316B50);
  static const danger = Color(0xFFA34336);
}

class CoffeeButton extends StatelessWidget {
  const CoffeeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.secondary = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool secondary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? CoffeeColors.danger : CoffeeColors.ink;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? CoffeeColors.cream : color,
          foregroundColor: secondary ? color : Colors.white,
          disabledBackgroundColor: CoffeeColors.border,
          disabledForegroundColor: CoffeeColors.muted,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'CiksSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CoffeeColors.ink,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19),
                    const SizedBox(width: 10),
                  ],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}

class CoffeeDialogFrame extends StatelessWidget {
  const CoffeeDialogFrame({
    super.key,
    required this.child,
    this.scrollable = false,
  });

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: math.max(
          0,
          media.size.height -
              media.viewInsets.bottom -
              media.padding.vertical -
              48,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: CoffeeColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: scrollable ? SingleChildScrollView(child: child) : child,
    );
  }
}

class CoffeeOptionTile extends StatelessWidget {
  const CoffeeOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: CoffeeColors.cream,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: CoffeeColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28, color: CoffeeColors.ink),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: CoffeeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      fontSize: 12,
                      height: 1.5,
                      color: CoffeeColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CoffeeColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 21,
              color: CoffeeColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

class CoffeeDialog extends StatelessWidget {
  const CoffeeDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.content,
    this.icon,
    this.accent = CoffeeColors.ink,
    this.dismissLabel = 'Tutup',
    this.dismissible = true,
  });

  final String title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final Color accent;
  final List<Widget> actions;
  final String dismissLabel;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    return CoffeeDialogFrame(
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: icon == null
                      ? const Center(child: BrandMark(size: 32))
                      : Icon(icon, size: 26, color: accent),
                ),
                if (dismissible)
                  IconButton(
                    tooltip: dismissLabel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: CoffeeColors.muted,
                      size: 21,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'CiksSans',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: CoffeeColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                style: const TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 14,
                  height: 1.65,
                  color: CoffeeColors.muted,
                ),
              ),
            ],
            if (content != null) ...[const SizedBox(height: 20), content!],
            const SizedBox(height: 24),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

Future<T?> showCoffeeSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: CoffeeColors.ink.withValues(alpha: 0.35),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: builder,
  );
}

class CoffeeSheet extends StatelessWidget {
  const CoffeeSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.dismissLabel = 'Tutup',
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(
            0,
            media.size.height * 0.92 - media.viewInsets.bottom,
          ),
        ),
        child: Material(
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CoffeeColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'CiksSans',
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: CoffeeColors.ink,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontFamily: 'CiksSans',
                                  fontSize: 13,
                                  color: CoffeeColors.muted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: dismissLabel,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: CoffeeColors.muted,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: child,
                  ),
                ),
                if (footer != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: CoffeeColors.border),
                      ),
                    ),
                    child: footer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
