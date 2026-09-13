import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FloatingWorkoutNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingWorkoutNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double navBarHeight = 76.0; // Altezza aumentata della barra

    return SizedBox(
      height: navBarHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, navBarHeight),
            painter: _NavBarPainter(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem('assets/icons/ic_home.svg', 0),
              _buildNavItem('assets/icons/ic_calendar.svg', 1),
              const SizedBox(
                width: 90, // Spazio allargato per la protuberanza centrale
              ),
              _buildNavItem('assets/icons/ic_bar_chart.svg', 3),
              _buildNavItem('assets/icons/ic_user.svg', 4),
            ],
          ),
          // Pulsante "+" riadattato e centrato
          // Pulsante "+" riadattato e centrato con ombra
          Positioned(
            top: -12, // Coordinata allineata con l'altezza e la curva
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.45,
                        ), // Ombra di profondità scura
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFFFF9700),
                    child: Icon(Icons.add, color: Colors.white, size: 42),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String svgPath, int index) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        color: Colors.transparent, // Aumenta l'area di tocco
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: SvgPicture.asset(
          svgPath,
          width: 38, // Icone ingrandite da 32 a 38
          height: 38,
          colorFilter: ColorFilter.mode(
            isSelected
                ? const Color(0xFFFF9700) // Colore primario attivo
                : Colors.white70, // Colore disattivato
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const double radius = 28.0;
    final double center = w / 2;

    // --- 1. COSTRUZIONE DEL PERCORSO SUPERIORE (PER L'OMBRA D'ACCENTO VERSO L'ALTO) ---
    final topEdgePath = Path();
    topEdgePath.moveTo(0, radius);
    topEdgePath.quadraticBezierTo(0, 0, radius, 0);
    topEdgePath.lineTo(center - 75, 0);
    topEdgePath.cubicTo(center - 38, 0, center - 32, -26, center, -26);
    topEdgePath.cubicTo(center + 32, -26, center + 38, 0, center + 75, 0);
    topEdgePath.lineTo(w - radius, 0);
    topEdgePath.quadraticBezierTo(w, 0, w, radius);

    // Ombra/glow superiore scura che proietta verso l'alto lungo il profilo della curva
    final Paint topShadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    // Eseguiamo un leggero offset negativo sull'asse Y per far risaltare l'ombra verso l'alto
    canvas.save();
    canvas.translate(0, -2.5);
    canvas.drawPath(topEdgePath, topShadowPaint);
    canvas.restore();

    // --- 2. COSTRUZIONE DEL CORPO COMPLETO DELLA CARD ---
    final path = Path();
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);

    path.lineTo(center - 75, 0);
    path.cubicTo(center - 38, 0, center - 32, -26, center, -26);
    path.cubicTo(center + 32, -26, center + 38, 0, center + 75, 0);

    path.lineTo(w - radius, 0);
    path.quadraticBezierTo(w, 0, w, radius);
    path.lineTo(w, h - radius);
    path.quadraticBezierTo(w, h, w - radius, h);
    path.lineTo(radius, h);
    path.quadraticBezierTo(0, h, 0, h - radius);
    path.close();

    // Ombra volumetrica globale del corpo della navbar
    canvas.drawShadow(path, Colors.black, 12.0, true);

    // Riempimento solido del fondo
    final paint =
        Paint()
          ..color = const Color(0xFF434343)
          ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Rifinitura del bordo superiore (sottile hairline illuminata per stacco netto)
    final Paint borderHighlight =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
    canvas.drawPath(topEdgePath, borderHighlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
