import 'package:flutter/material.dart';

class DebugBubble extends StatefulWidget {
  const DebugBubble({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<DebugBubble> createState() => _DebugBubbleState();
}

class _DebugBubbleState extends State<DebugBubble>
    with TickerProviderStateMixin {
  Offset _offset = Offset.zero;
  bool _dragging = false;
  bool _initialized = false;

  late AnimationController _pulseController;
  late AnimationController _scaleController;

  static const double size = 60.0;
  static const double margin = 16.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _initPosition(BuildContext context) {
    if (_initialized) return;

    final media = MediaQuery.of(context);
    final padding = media.padding;

    _offset = Offset(
      media.size.width - size - margin,
      media.size.height - size - padding.bottom - 50 - margin,
    );

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _initPosition(context);

    final media = MediaQuery.of(context);
    final padding = media.padding;

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onTap: () {
          if (!_dragging) {
            _scaleController.forward().then((_) {
              _scaleController.reverse();
            });
            widget.onTap();
          }
        },
        onPanStart: (_) {
          setState(() => _dragging = true);
          _scaleController.forward();
        },
        onPanEnd: (_) {
          _scaleController.reverse();

          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) setState(() => _dragging = false);
          });
        },
        onPanUpdate: (d) {
          setState(() {
            _offset = Offset(
              (_offset.dx + d.delta.dx).clamp(
                margin,
                media.size.width - size - margin,
              ),
              (_offset.dy + d.delta.dy).clamp(
                padding.top + margin,
                media.size.height - size - padding.bottom - margin,
              ),
            );
          });
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _scaleController]),
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_scaleController.value * 0.1),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse
                  Container(
                    width: size + (20 * _pulseController.value),
                    height: size + (20 * _pulseController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.deepPurple.withValues(
                          alpha: 0.5 * (1 - _pulseController.value),
                        ),
                        width: 2,
                      ),
                    ),
                  ),

                  // Bubble
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.deepPurple[400]!,
                          Colors.deepPurple[700]!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bug_report_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'DBG',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
