import 'package:flutter/material.dart';

/// A smooth, modern page transition: the incoming screen slides in from the
/// right (respecting text direction) while fading in, and reverses on pop.
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
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (_, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: curve,
              reverseCurve: curve,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Shared slide + fade [TransitionSequenceBuilder] used by [MainShell]'s
/// [AnimatedSwitcher] so screen swaps inside the shell feel identical to
/// pushed routes.
Widget shellScreenTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
          .animate(curved),
      child: child,
    ),
  );
}
