import 'package:flutter/material.dart';

/// A smooth, modern page transition: the incoming screen gently slides in from
/// the right while scaling up from 96% and fading in, using a quick "fast-out"
/// ease for a premium settle. Popping runs a shorter, snappier reverse.
///
/// Use it anywhere a real route is pushed:
/// ```dart
/// Navigator.of(context).push(
///   SlideFadeRoute(const EditProfileScreen()),
/// );
/// ```
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

/// Shared slide + fade [TransitionSequenceBuilder] used by [MainShell]'s
/// [AnimatedSwitcher] so screen swaps inside the shell feel identical to
/// pushed routes.
Widget shellScreenTransition(Widget child, Animation<double> animation) {
  final curved =
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
      child: SlideTransition(
        position:
            Tween<Offset>(begin: const Offset(0.045, 0), end: Offset.zero)
                .animate(curved),
        child: child,
      ),
    ),
  );
}
