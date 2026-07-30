import 'package:flutter/material.dart';

/// Branded "AHVI is working" indicator:  ✦  <message>  • • •
///
/// A single ~1.2s controller drives a gently pulsing sparkle and three
/// sequentially fading dots. Compact rounded bubble consistent with assistant
/// messages. Respects [MediaQueryData.disableAnimations] by rendering a static
/// indicator (no running controller). Reusable from chat and the Style This
/// modal — [_TypingBubble] delegates to it.
class AhviProcessingBubble extends StatefulWidget {
  final String message;

  const AhviProcessingBubble({super.key, required this.message});

  @override
  State<AhviProcessingBubble> createState() => _AhviProcessingBubbleState();
}

class _AhviProcessingBubbleState extends State<AhviProcessingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animationsEnabled = !MediaQuery.disableAnimationsOf(context);
    // Drive or halt the single controller from build — never create/dispose
    // it here.
    if (animationsEnabled) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else if (_ctrl.isAnimating) {
      _ctrl.stop();
    }
    final controller = animationsEnabled ? _ctrl : null;

    final sparkle = Text(
      '✦',
      style: TextStyle(
        color: scheme.primary,
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w600,
      ),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        controller == null
            ? sparkle
            : ScaleTransition(
                scale: Tween<double>(begin: 0.82, end: 1.0).animate(
                  CurvedAnimation(
                    parent: controller,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: sparkle,
              ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Dots(controller: controller, color: scheme.primary),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: content,
    );
  }
}

/// Three dots. When [controller] is null (animations disabled) they render at
/// a fixed mid opacity — a static indicator.
class _Dots extends StatelessWidget {
  final AnimationController? controller;
  final Color color;
  const _Dots({required this.controller, required this.color});

  static const _count = 3;

  @override
  Widget build(BuildContext context) {
    Widget dot(double opacity, {double margin = 0}) => Container(
          margin: EdgeInsets.only(right: margin),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );

    final ctrl = controller;
    if (ctrl == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          _count,
          (i) => dot(0.6, margin: i < _count - 1 ? 4 : 0),
        ),
      );
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_count, (i) {
          // Sequential fade: each dot peaks a third of a cycle after the last.
          final phase = (ctrl.value - i / _count) % 1.0;
          // Triangle wave 0→1→0 so the dot fades in then out.
          final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
          final opacity = 0.3 + 0.7 * wave.clamp(0.0, 1.0);
          return dot(opacity, margin: i < _count - 1 ? 4 : 0);
        }),
      ),
    );
  }
}
