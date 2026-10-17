import 'package:flutter/material.dart';

/// Custom PageRouteBuilder that provides a seamless, ultra-smooth upward sliding
/// transition for auth screens (Login, Signup, Reset Password).
/// With opaque: false, the underlying screen's background and secondary
/// animation blend continuously without background flicker or blank frames.
Route<T> createAuthSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    opaque: false,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}
