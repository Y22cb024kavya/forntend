import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // This is the release splash gate. AuthWrapper still decides the route.
  static const _autoNavDelay = Duration(milliseconds: 2000);

  late final AnimationController _controller;
  late final Animation<double> _letterFade;
  late final Animation<double> _motionBlur;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _offsetA;
  late final Animation<Offset> _offsetH;
  late final Animation<Offset> _offsetV;
  late final Animation<Offset> _offsetI;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _letterFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _motionBlur = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.72, curve: Curves.easeOut),
      ),
    );

    final slideCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.72, curve: Curves.easeOutCubic),
    );
    _offsetA = Tween<Offset>(
      begin: const Offset(-0.30, -0.30),
      end: Offset.zero,
    ).animate(slideCurve);
    _offsetH = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(slideCurve);
    _offsetV = Tween<Offset>(
      begin: const Offset(0.0, -0.35),
      end: Offset.zero,
    ).animate(slideCurve);
    _offsetI = Tween<Offset>(
      begin: const Offset(0.30, 0.30),
      end: Offset.zero,
    ).animate(slideCurve);

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.9, curve: Curves.easeIn),
      ),
    );

    _finishTimer = Timer(_autoNavDelay, () {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAnimatedLetter(
    String letter,
    Animation<Offset> offset,
    double logoSize,
  ) {
    final movement = logoSize / 84.0 * 120.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(offset.value.dx * movement, offset.value.dy * movement),
        child: Opacity(
          opacity: _letterFade.value,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _motionBlur.value,
              sigmaY: _motionBlur.value,
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontFamily: 'Anton',
                fontSize: logoSize,
                color: Colors.white,
                letterSpacing: logoSize * 0.0476,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: Center(child: _buildBrandSection())),
      ),
    );
  }

  Widget _buildBrandSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoSize = math.min(
          84.0,
          math.max(64.0, constraints.maxWidth * 0.22),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: constraints.maxWidth * 0.90,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedLetter('A', _offsetA, logoSize),
                    _buildAnimatedLetter('H', _offsetH, logoSize),
                    _buildAnimatedLetter('V', _offsetV, logoSize),
                    _buildAnimatedLetter('I', _offsetI, logoSize),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _taglineFade,
              child: Text(
                'STYLE • PREP • PLAN',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  letterSpacing: 3.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
