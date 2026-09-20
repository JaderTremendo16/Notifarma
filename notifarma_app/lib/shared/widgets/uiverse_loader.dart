import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Animated rotating orb loader with undulating letter text
/// Based on UIverse.io by pradip_1434
class UiverseLoader extends StatefulWidget {
  final String text;
  final double size;
  final TextStyle? textStyle;
  final Color? textColor;

  const UiverseLoader({
    super.key,
    this.text = 'Cargando...',
    this.size = 20.0,
    this.textStyle,
    this.textColor,
  });

  @override
  State<UiverseLoader> createState() => _UiverseLoaderState();
}

class _UiverseLoaderState extends State<UiverseLoader> with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _textController;

  @override
  void initState() {
    super.initState();
    // 1.5s linear rotation for the orb
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // 2.0s letter wave animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = widget.textColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    final effectiveTextStyle = (widget.textStyle ??
            GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ))
        .copyWith(color: defaultColor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Glowing Orb with dynamic rotation
        AnimatedBuilder(
          animation: _orbController,
          builder: (context, child) {
            final t = _orbController.value;
            final angle = t * 2 * math.pi;

            // Simulates color shift in @keyframes loader-rotate
            final Color topShadow = Color.lerp(
              const Color(0xFFFF5F9F),
              const Color(0xFFD60A47),
              (math.sin(angle) + 1) / 2,
            )!;

            final Color bottomShadow = Color.lerp(
              const Color(0xFF0693FF),
              const Color(0xFFFBEF19),
              (math.cos(angle) + 1) / 2,
            )!;

            return Transform.rotate(
              angle: angle,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.white,
                      topShadow,
                      bottomShadow,
                      Colors.white,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: topShadow.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: bottomShadow.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: widget.size * 0.45,
                    height: widget.size * 0.45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),

        // Letter-by-letter wave animation
        AnimatedBuilder(
          animation: _textController,
          builder: (context, child) {
            final characters = widget.text.split('');
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(characters.length, (index) {
                final char = characters[index];
                // Stagger delay based on CSS nth-child delay (0.1s step per char in a 2s cycle)
                final delay = (index * 0.08) % 1.0;
                final shiftedProgress = (_textController.value - delay + 1.0) % 1.0;

                double opacity = 0.4;
                double scale = 1.0;

                if (shiftedProgress >= 0.0 && shiftedProgress <= 0.2) {
                  final subT = shiftedProgress / 0.2;
                  opacity = 0.4 + (0.6 * subT);
                  scale = 1.0 + (0.2 * subT);
                } else if (shiftedProgress > 0.2 && shiftedProgress <= 0.4) {
                  final subT = (shiftedProgress - 0.2) / 0.2;
                  opacity = 1.0 - (0.3 * subT);
                  scale = 1.2 - (0.2 * subT);
                } else if (shiftedProgress > 0.4 && shiftedProgress <= 0.6) {
                  final subT = (shiftedProgress - 0.4) / 0.2;
                  opacity = 0.7 - (0.3 * subT);
                  scale = 1.0;
                } else {
                  opacity = 0.4;
                  scale = 1.0;
                }

                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity.clamp(0.2, 1.0),
                    child: Text(
                      char,
                      style: effectiveTextStyle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
