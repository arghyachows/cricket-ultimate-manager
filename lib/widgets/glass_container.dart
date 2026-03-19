import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable Apple-style glassmorphism container.
///
/// Wraps its child in a frosted-glass surface with backdrop blur, a
/// translucent tinted background, and a subtle white highlight border.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final double opacity;
  final double borderOpacity;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.blur = 20,
    this.tint,
    this.opacity = 0.08,
    this.borderOpacity = 0.15,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTint = tint ?? Colors.white;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveTint.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: borderOpacity),
                    width: 0.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
