import 'package:flutter/material.dart';

import 'localization.dart';

const paper = Color(0xFFFFF9EB);
const ink = Color(0xFF28382F);
const marker = Color(0xFFF6DD83);

ThemeData tandaTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final paper = dark ? const Color(0xFF20261F) : const Color(0xFFFFF9EB);
  final ink = dark ? const Color(0xFFEDE7D6) : const Color(0xFF28382F);
  final marker = dark ? const Color(0xFF746027) : const Color(0xFFF6DD83);
  final card = dark ? const Color(0xFF2B332B) : const Color(0xFFFFFDF5);
  final outline = dark ? const Color(0xFF9BA995) : const Color(0xFF9CABA0);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF30664F),
          surface: paper,
          brightness: brightness,
        ).copyWith(
          onSurface: ink,
          primary: dark ? const Color(0xFFA2CDAF) : const Color(0xFF30664F),
          onPrimary: dark ? const Color(0xFF183523) : Colors.white,
          surfaceContainer: card,
          tertiaryContainer: marker,
          onTertiaryContainer: ink,
        ),
  );
  final text = base.textTheme.apply(bodyColor: ink, displayColor: ink);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: text.copyWith(
      headlineLarge: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.1,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.15,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.15,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 29,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 35,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: SketchBorder(color: ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? const Color(0xFF303A30)
          : Colors.white.withValues(alpha: 0.8),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ink, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: SketchBorder(color: dark ? ink : const Color(0xFF244D3B)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: SketchBorder(color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selectedColor: marker,
      backgroundColor: paper,
      padding: const EdgeInsets.all(10),
      side: BorderSide(color: outline),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper,
      indicatorColor: marker,
      height: 72,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: paper,
      shape: SketchBorder(color: ink),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: paper),
    ),
  );
}

/// Stable, slightly uneven outlines. Decoration never changes the hit region.
class SketchBorder extends OutlinedBorder {
  const SketchBorder({this.color = ink, super.side = BorderSide.none});
  final Color color;
  @override
  SketchBorder copyWith({BorderSide? side}) =>
      SketchBorder(color: color, side: side ?? this.side);
  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(1.5);
  @override
  ShapeBorder scale(double t) => SketchBorder(color: color);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect.deflate(1));
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect.deflate(2));
  Path _outline(Rect r) => Path()
    ..moveTo(r.left + 16, r.top + 1)
    ..quadraticBezierTo(r.center.dx, r.top - 1, r.right - 15, r.top + 2)
    ..quadraticBezierTo(r.right, r.top + 1, r.right - 1, r.top + 17)
    ..lineTo(r.right - 2, r.bottom - 15)
    ..quadraticBezierTo(r.right, r.bottom, r.right - 17, r.bottom - 1)
    ..quadraticBezierTo(r.center.dx, r.bottom + 1, r.left + 15, r.bottom - 2)
    ..quadraticBezierTo(r.left, r.bottom, r.left + 1, r.bottom - 16)
    ..lineTo(r.left + 2, r.top + 16)
    ..quadraticBezierTo(r.left, r.top, r.left + 16, r.top + 1)
    ..close();
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
      getOuterPath(rect),
      Paint()
        ..color = color.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }
}

class PaperBackdrop extends StatelessWidget {
  const PaperBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: CustomPaint(
      painter: _PaperPainter(Theme.of(context).brightness),
      child: child,
    ),
  );
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.brightness);
  final Brightness brightness;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color =
          (brightness == Brightness.dark
                  ? const Color(0xFFEDE7D6)
                  : const Color(0xFF77734C))
              .withValues(alpha: brightness == Brightness.dark ? 0.06 : 0.045)
      ..strokeWidth = 1;
    for (var y = 16.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 0.8), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) =>
      brightness != oldDelegate.brightness;
}

class NotebookHeader extends StatelessWidget {
  const NotebookHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 12,
                    bottom: 3,
                    child: Transform.rotate(
                      angle: -0.015,
                      child: Container(
                        height: 10,
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                      ),
                    ),
                  ),
                  UiText(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              UiText(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Transform.rotate(
          angle: 0.08,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: ShapeDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              shape: SketchBorder(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
}
