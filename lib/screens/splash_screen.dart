import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/brand_mark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: BrandMark.cream,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: BrandMark.cream,
        body: Stack(
          children: [
            const Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _CoffeeContours()),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, viewport) => Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Text(
                        'SEJENAK UNTUK RASA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'CiksSans',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3,
                          color: Color(0xFF806B5B),
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, space) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: space.maxHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 24,
                              ),
                              child: Center(
                                child: FadeTransition(
                                  opacity: _entrance,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.035),
                                      end: Offset.zero,
                                    ).animate(_entrance),
                                    child: _SplashIdentity(
                                      compact: viewport.maxHeight < 620,
                                      landscape:
                                          viewport.maxWidth >
                                          viewport.maxHeight * 1.25,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _LoadingFooter(reduceMotion: reduceMotion),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashIdentity extends StatelessWidget {
  const _SplashIdentity({required this.compact, required this.landscape});

  final bool compact;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: landscape
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          'Ciks Coffee',
          textAlign: landscape ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontFamily: 'CiksDisplay',
            fontSize: compact ? 36 : 42,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.1,
            height: 1.2,
            color: BrandMark.espresso,
          ),
        ),
        SizedBox(height: landscape ? 16 : 24),
        Container(width: 28, height: 1, color: const Color(0xFFC5A583)),
        SizedBox(height: landscape ? 16 : 24),
        Text(
          'Rasa yang akrab.\nJeda yang berarti.',
          textAlign: landscape ? TextAlign.start : TextAlign.center,
          style: const TextStyle(
            fontFamily: 'CiksSans',
            fontSize: 14,
            height: 1.8,
            color: Color(0xFF806B5B),
          ),
        ),
      ],
    );
    return landscape
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 112),
              const SizedBox(width: 40),
              Flexible(child: copy),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: compact ? 96 : 136),
              SizedBox(height: compact ? 20 : 28),
              copy,
            ],
          );
  }
}

class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter({required this.reduceMotion});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Semantics(
        label: 'Memuat Ciks Coffee',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 2,
                child: reduceMotion
                    ? const ColoredBox(
                        color: Color(0xFFE8DED3),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 2,
                            child: ColoredBox(color: BrandMark.espresso),
                          ),
                        ),
                      )
                    : const LinearProgressIndicator(
                        color: BrandMark.espresso,
                        backgroundColor: Color(0xFFE8DED3),
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SEBENTAR, YA...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.4,
                  color: Color(0xFF806B5B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet cup-ring contours, drawn locally so the splash works fully offline.
class _CoffeeContours extends CustomPainter {
  const _CoffeeContours();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8DED3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final radius = math.min(size.width * 0.65, 290.0);
    final upper = Offset(size.width + radius * 0.18, size.height * 0.1);
    final lower = Offset(-radius * 0.4, size.height * 0.86);
    for (var index = 0; index < 3; index++) {
      canvas.drawCircle(upper, radius + index * 16, paint);
      canvas.drawCircle(lower, radius * 0.75 + index * 16, paint);
    }
  }

  @override
  bool shouldRepaint(_CoffeeContours oldDelegate) => false;
}
