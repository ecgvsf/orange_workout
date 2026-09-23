import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    const double navBarHeight = 76.0;

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
              _buildAnimatedNavItem('assets/icons/ic_home.svg', 0),
              _buildAnimatedNavItem('assets/icons/ic_calendar.svg', 1),
              const SizedBox(width: 90), // Spazio per la protuberanza centrale
              _buildAnimatedNavItem('assets/icons/ic_bar_chart.svg', 3),
              _buildAnimatedNavItem('assets/icons/ic_user.svg', 4),
            ],
          ),
          // Pulsante centrale "+"
          Positioned(
            top: -12,
            left: 0,
            right: 0,
            child: Center(child: _CentralButton(onTap: () => onTap(2))),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedNavItem(String svgPath, int index) {
    // Rimappatura indice visivo (3->2, 4->3 per saltare il tasto + centrale)
    final mappedTarget = index > 2 ? index - 1 : index;
    final isSelected = currentIndex == mappedTarget;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(index);
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: AnimatedScale(
          scale: isSelected ? 1.08 : 0.95,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutQuad,
          child: AnimatedOpacity(
            opacity: isSelected ? 1.0 : 0.60,
            duration: const Duration(milliseconds: 200),
            child: SvgPicture.asset(
              svgPath,
              width: 38,
              height: 38,
              colorFilter: ColorFilter.mode(
                isSelected ? const Color(0xFFFF9700) : Colors.white70,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CentralButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CentralButton({required this.onTap});

  @override
  State<_CentralButton> createState() => _CentralButtonState();
}

class _CentralButtonState extends State<_CentralButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutQuad,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
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

    final topEdgePath = Path();
    topEdgePath.moveTo(0, radius);
    topEdgePath.quadraticBezierTo(0, 0, radius, 0);
    topEdgePath.lineTo(center - 75, 0);
    topEdgePath.cubicTo(center - 38, 0, center - 32, -26, center, -26);
    topEdgePath.cubicTo(center + 32, -26, center + 38, 0, center + 75, 0);
    topEdgePath.lineTo(w - radius, 0);
    topEdgePath.quadraticBezierTo(w, 0, w, radius);

    final Paint topShadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    canvas.save();
    canvas.translate(0, -2.5);
    canvas.drawPath(topEdgePath, topShadowPaint);
    canvas.restore();

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

    canvas.drawShadow(path, Colors.black, 12.0, true);

    final paint =
        Paint()
          ..color = const Color(0xFF2C2C2E)
          ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

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
