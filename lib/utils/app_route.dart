import 'package:flutter/material.dart';

class SlideFadeRoute<T> extends PageRouteBuilder<T> {
  SlideFadeRoute(
    Widget child, {
    Duration duration = const Duration(milliseconds: 320),
    Duration reverseDuration = const Duration(milliseconds: 240),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (_, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
}

Widget shellScreenTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.045, 0), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    ),
  );
}
