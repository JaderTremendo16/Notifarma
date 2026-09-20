import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated Sun/Moon toggle based on UIverse.io by satyamchaudharydev (shy-earwig-18)
/// Perfect alignment, smooth 450ms cubic-bezier transition, rotation and realistic crescent moon.
class ThemeToggleSwitch extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const ThemeToggleSwitch({
    super.key,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<ThemeToggleSwitch> createState() => _ThemeToggleSwitchState();
}

class _ThemeToggleSwitchState extends State<ThemeToggleSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: widget.isDark ? 1.0 : 0.0,
    );

    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  void didUpdateWidget(covariant ThemeToggleSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDark != oldWidget.isDark) {
      if (widget.isDark) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final nextState = !widget.isDark;
    if (nextState) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onChanged(nextState);
  }

  @override
  Widget build(BuildContext context) {
    // Standard dimensions matching CSS 3.5em x 2em with 1.4em icon and 0.3em offset
    const double width = 64.0;
    const double height = 36.0;
    const double iconSize = 26.0;
    const double padding = 4.0;
    const double maxSlide = width - iconSize - (padding * 2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            final progress = _slideAnimation.value;

            // Background color interpolation
            final bgColor = Color.lerp(
              const Color(0xFFF4F4F5),
              const Color(0xFF303136),
              progress,
            )!;

            final borderColor = Color.lerp(
              const Color(0xFFE2E8F0),
              const Color(0xFF475569),
              progress,
            )!;

            return Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Animated sliding icon
                  Positioned(
                    left: padding + (maxSlide * progress),
                    child: Transform.rotate(
                      angle: progress * -math.pi * 0.3,
                      child: SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: CustomPaint(
                          painter: _SunMoonPainter(progress: progress),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// CustomPainter that faithfully draws the CSS Sun & Moon with smooth morphing and shadows
class _SunMoonPainter extends CustomPainter {
  final double progress;

  _SunMoonPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (progress < 0.5) {
      // ─── SUN STATE (linear-gradient(40deg, #ff0080, #ff8c00 70%)) ───
      final sunOpacity = (1.0 - progress * 2).clamp(0.0, 1.0);
      final sunPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0xFFFF0080),
            Color(0xFFFF8C00),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..color = Colors.white.withValues(alpha: sunOpacity);

      // Subtle warm sun glow
      final glowPaint = Paint()
        ..color = const Color(0xFFFF8C00).withValues(alpha: 0.35 * sunOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(center, radius, glowPaint);
      canvas.drawCircle(center, radius, sunPaint);
    } else {
      // ─── MOON STATE (CSS #303136 + inset -3px -2px #8983f7, -10px -4px #a3dafb) ───
      final moonProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);

      // 1. Base dark circle (#303136)
      final baseMoonPaint = Paint()..color = const Color(0xFF303136);
      canvas.drawCircle(center, radius, baseMoonPaint);

      // 2. Draw outer luminous glowing crescent
      canvas.saveLayer(Rect.fromCircle(center: center, radius: radius), Paint());

      // Base mask for icon bounds
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      );

      // Neon purple glow layer
      final purpleGlow = Paint()
        ..color = const Color(0xFF8983F7).withValues(alpha: 0.9 * moonProgress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(center.translate(-1.5, -0.8), radius, purpleGlow);

      // Bright cyan blue crescent inner shadow
      final cyanMoon = Paint()
        ..color = const Color(0xFFA3DAFB).withValues(alpha: 0.95 * moonProgress);
      canvas.drawCircle(center.translate(-3.0, -1.2), radius * 0.96, cyanMoon);

      // Inner dark mask to create the crisp crescent curve
      final innerShadowMask = Paint()
        ..color = const Color(0xFF303136)
        ..blendMode = BlendMode.srcOver;
      canvas.drawCircle(center.translate(3.5, 0.8), radius * 0.82, innerShadowMask);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SunMoonPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
