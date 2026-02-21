import 'dart:math';
import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';

/// Analog clock palette with Liquid Glass effect.
///
/// Demonstrates `keepAlive` (continues ticking when unfocused),
/// `alwaysOnTop` (stays above all windows), and circular glass masking.
class ClockPalette extends StatefulWidget {
  const ClockPalette({super.key});

  @override
  State<ClockPalette> createState() => _ClockPaletteState();
}

class _ClockPaletteState extends State<ClockPalette>
    with SingleTickerProviderStateMixin {
  static const double _size = 200;
  static const double _glassRadius = _size / 2 * 0.85;

  final GlassEffectService _glassService = GlassEffectService();
  late AnimationController _animController;
  String? _windowId;
  bool _glassEnabled = false;

  @override
  void initState() {
    super.initState();

    // Clock display: tick at display refresh rate for smooth second hand
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _animController.repeat();

    // Initialize glass after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGlass();
    });
  }

  Future<void> _initGlass() async {
    _windowId = PaletteWindow.currentId;
    if (_windowId == null || !_glassService.isAvailable) return;

    final success = _glassService.enable(_windowId!);
    if (success && mounted) {
      setState(() => _glassEnabled = true);
      _updateGlassPath();
    }
  }

  void _updateGlassPath() {
    if (_windowId == null || !_glassEnabled) return;

    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: const Offset(_size / 2, _size / 2),
          radius: _glassRadius,
        ),
      );
    _glassService.updatePath(_windowId!, path, windowHeight: _size);
  }

  @override
  void dispose() {
    _animController.dispose();
    if (_windowId != null) {
      _glassService.disable(_windowId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          onPanStart: (_) => PaletteWindow.startDrag(),
          child: PaletteScaffold(
            backgroundColor: Colors.transparent,
            cornerRadius: 0,
            child: SizedBox(
              width: _size,
              height: _size,
              child: CustomPaint(
                painter: _ClockPainter(
                  dateTime: DateTime.now(),
                  glassEnabled: _glassEnabled,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that draws an analog clock face.
/// Designed to layer on top of the native Liquid Glass effect.
class _ClockPainter extends CustomPainter {
  final DateTime dateTime;
  final bool glassEnabled;

  _ClockPainter({required this.dateTime, required this.glassEnabled});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;

    // Hour marks
    final hourMarkPaint = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * pi / 180 - pi / 2;
      final outer =
          center + Offset(cos(angle) * (radius - 8), sin(angle) * (radius - 8));
      final inner =
          center +
          Offset(cos(angle) * (radius - 20), sin(angle) * (radius - 20));
      canvas.drawLine(inner, outer, hourMarkPaint);
    }

    // Minute marks
    final minuteMarkPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      if (i % 5 == 0) continue;
      final angle = (i * 6) * pi / 180 - pi / 2;
      final outer =
          center + Offset(cos(angle) * (radius - 8), sin(angle) * (radius - 8));
      final inner =
          center +
          Offset(cos(angle) * (radius - 14), sin(angle) * (radius - 14));
      canvas.drawLine(inner, outer, minuteMarkPaint);
    }

    // Date display below center
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                     'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dayLabel = weekdays[dateTime.weekday - 1];
    final monthLabel = months[dateTime.month - 1];
    final dayNumber = '${dateTime.day}';

    final dateY = center.dy + radius * 0.32;

    final weekdayPainter = TextPainter(
      text: TextSpan(
        text: dayLabel,
        style: const TextStyle(
          color: Color(0x77FFFFFF),
          fontSize: 9,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.5,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final datePainter = TextPainter(
      text: TextSpan(
        text: '$monthLabel $dayNumber',
        style: const TextStyle(
          color: Color(0x99FFFFFF),
          fontSize: 14,
          fontWeight: FontWeight.w200,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalHeight = weekdayPainter.height + 2 + datePainter.height;
    final topY = dateY - totalHeight / 2;

    weekdayPainter.paint(
      canvas,
      Offset(center.dx - weekdayPainter.width / 2, topY),
    );
    datePainter.paint(
      canvas,
      Offset(center.dx - datePainter.width / 2, topY + weekdayPainter.height + 2),
    );

    final hour = dateTime.hour % 12;
    final minute = dateTime.minute;
    final second = dateTime.second;
    final millisecond = dateTime.millisecond;

    // Hour hand
    final hourAngle = ((hour + minute / 60) * 30) * pi / 180 - pi / 2;
    final hourHandPaint = Paint()
      ..color = const Color(0x77FFFFFF)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    final hourEnd =
        center +
        Offset(
          cos(hourAngle) * (radius * 0.45),
          sin(hourAngle) * (radius * 0.45),
        );
    canvas.drawLine(center, hourEnd, hourHandPaint);

    // Minute hand
    final minuteAngle = ((minute + second / 60) * 6) * pi / 180 - pi / 2;
    final minuteHandPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final minuteEnd =
        center +
        Offset(
          cos(minuteAngle) * (radius * 0.65),
          sin(minuteAngle) * (radius * 0.65),
        );
    canvas.drawLine(center, minuteEnd, minuteHandPaint);

    // Second hand (smooth sweep using milliseconds)
    final smoothSecond = second + millisecond / 1000.0;
    final secondAngle = (smoothSecond * 6) * pi / 180 - pi / 2;
    final secondHandPaint = Paint()
      ..color = const Color(0x55FF6B6B)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    final secondEnd =
        center +
        Offset(
          cos(secondAngle) * (radius * 0.72),
          sin(secondAngle) * (radius * 0.72),
        );
    final secondTail =
        center +
        Offset(
          cos(secondAngle + pi) * (radius * 0.15),
          sin(secondAngle + pi) * (radius * 0.15),
        );
    canvas.drawLine(secondTail, secondEnd, secondHandPaint);

    // Center dot
    final centerDotPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.0, centerDotPaint);

    final centerDotBorder = Paint()
      ..color = const Color(0x44FF6B6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, 3.0, centerDotBorder);
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) => true;
}
