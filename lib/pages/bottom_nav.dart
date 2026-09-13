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
                          alpha: 0.55,
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
    final paint =
        Paint()
          ..color = const Color(0xFF2C2C2E)
          ..style = PaintingStyle.fill;

    final path = Path();
    final double w = size.width;
    final double h = size.height;
    const double radius = 28.0; // Raggio degli angoli smussati

    final double center = w / 2;

    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);

    // Curva di Bézier ammorbidita e proporzionata alla nuova altezza
    path.lineTo(center - 75, 0);
    path.cubicTo(
      center - 38,
      0, // Controllo inferiore sx
      center - 32,
      -26, // Controllo superiore sx
      center,
      -26, // Picco centrale
    );
    path.cubicTo(
      center + 32,
      -26, // Controllo superiore dx
      center + 38,
      0, // Controllo inferiore dx
      center + 75,
      0, // Ritorno alla linea piana
    );

    path.lineTo(w - radius, 0);
    path.quadraticBezierTo(w, 0, w, radius);
    path.lineTo(w, h - radius);
    path.quadraticBezierTo(w, h, w - radius, h);
    path.lineTo(radius, h);
    path.quadraticBezierTo(0, h, 0, h - radius);
    path.close();

    canvas.drawShadow(path, Colors.black, 10.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
