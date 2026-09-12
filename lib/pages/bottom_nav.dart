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
    return SizedBox(
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 70),
            painter: _NavBarPainter(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem('assets/icons/ic_home.svg', 0),
              _buildNavItem('assets/icons/ic_calendar.svg', 1),
              const SizedBox(
                width: 80,
              ), // Lo spazio centrale per la tua protuberanza col tasto "+"
              _buildNavItem('assets/icons/ic_bar_chart.svg', 3),
              _buildNavItem('assets/icons/ic_user.svg', 4),
            ],
          ),
          // Pulsante "+" ingrandito e centrato matematicamente
          Positioned(
            top: -6, // Rialzato per allinearsi al picco della curva
            left: 0,
            right: 0,
            child: Center(
              // Forza il centraggio orizzontale assoluto
              child: GestureDetector(
                onTap: () => onTap(2),
                child: const CircleAvatar(
                  radius: 28, // Aumentato da 28 a 34
                  backgroundColor: Color(0xFFFF9700),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 38,
                  ), // Icona più grande
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
        color: Colors.transparent, // Aumenta l'area toccabile
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SvgPicture.asset(
          svgPath,
          width: 32,
          height: 32,
          // Cambia colore in base allo stato della tab
          colorFilter: ColorFilter.mode(
            isSelected
                ? const Color(
                  0xFFFF9700,
                ) // Il colore primario per la tab attiva
                : Colors.white70, // Colore desaturato per le tab inattive
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
    const double radius = 24.0;

    // Identifica il centro esatto della barra
    final double center = w / 2;

    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);

    // Disegna la curva di Bézier morbida e larga
    path.lineTo(center - 65, 0);
    path.cubicTo(
      center - 30,
      0, // Punto di controllo inferiore sinistro
      center - 25,
      -20, // Punto di controllo superiore sinistro
      center,
      -20, // Picco centrale esatto
    );
    path.cubicTo(
      center + 25,
      -20, // Punto di controllo superiore destro
      center + 30,
      0, // Punto di controllo inferiore destro
      center + 65,
      0, // Ritorno alla linea piana
    );

    path.lineTo(w - radius, 0);
    path.quadraticBezierTo(w, 0, w, radius);
    path.lineTo(w, h - radius);
    path.quadraticBezierTo(w, h, w - radius, h);
    path.lineTo(radius, h);
    path.quadraticBezierTo(0, h, 0, h - radius);
    path.close();

    canvas.drawShadow(path, Colors.black, 8.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
