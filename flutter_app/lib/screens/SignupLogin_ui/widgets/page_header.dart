import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      height: size.height * 0.28,
      color: const Color(0xFFEEF1F3),
      alignment: Alignment.bottomCenter,
      child: Image.asset(
        'assets/images/friendship.png',
        fit: BoxFit.contain,
        height: size.height * 0.26,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.person_outline_rounded,
              size: 72,
              color: Color(0xFF233743),
            ),
          );
        },
      ),
    );
  }
}
