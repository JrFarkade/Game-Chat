import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class PttButton extends StatefulWidget {
  final bool isPressed;
  final ValueChanged<bool> onStateChanged;

  const PttButton({
    Key? key,
    required this.isPressed,
    required this.onStateChanged,
  }) : super(key: key);

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    HapticFeedback.heavyImpact();
    _controller.forward();
    widget.onStateChanged(true);
  }

  void _handleTapUp(TapUpDetails _) {
    HapticFeedback.lightImpact();
    _controller.reverse();
    widget.onStateChanged(false);
  }

  void _handleTapCancel() {
    _controller.reverse();
    widget.onStateChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isPressed;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.greenActive : AppColors.card,
                border: Border.all(
                  color: active ? AppColors.greenActive : AppColors.primary,
                  width: active ? 4 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: active ? AppColors.greenGlow : AppColors.primaryGlow,
                    blurRadius: active ? 30 : 15,
                    spreadRadius: active ? 6 : 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic,
                    size: 48,
                    color: active ? Colors.black : AppColors.textPrimary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    active ? 'TRANSMITTING' : 'HOLD TO TALK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: active ? Colors.black : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
