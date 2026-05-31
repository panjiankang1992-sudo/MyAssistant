import 'package:flutter/material.dart';

class EdgeSwipePop extends StatefulWidget {
  final Widget child;
  final double edgeWidth;

  const EdgeSwipePop({super.key, required this.child, this.edgeWidth = 34});

  @override
  State<EdgeSwipePop> createState() => _EdgeSwipePopState();
}

class _EdgeSwipePopState extends State<EdgeSwipePop> {
  bool _tracking = false;
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        _tracking = details.localPosition.dx <= widget.edgeWidth;
        _drag = 0;
      },
      onHorizontalDragUpdate: (details) {
        if (!_tracking) return;
        _drag += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        if (!_tracking) return;
        final velocity = details.primaryVelocity ?? 0;
        if (_drag > 80 || velocity > 420) {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            final rootNavigator = Navigator.of(context, rootNavigator: true);
            if (rootNavigator.canPop()) rootNavigator.pop();
          }
        }
        _tracking = false;
        _drag = 0;
      },
      child: widget.child,
    );
  }
}
