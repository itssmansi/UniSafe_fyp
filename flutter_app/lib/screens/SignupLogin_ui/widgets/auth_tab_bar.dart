import 'package:flutter/material.dart';

class AuthTabBar extends StatelessWidget {
  final int selectedIndex; // 0 = Log In, 1 = Sign Up
  final ValueChanged<int> onTabChanged;

  const AuthTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Login Tab
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selectedIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selectedIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selectedIndex == 0 ? FontWeight.w700 : FontWeight.w600,
                      color: selectedIndex == 0
                          ? const Color(0xFF133838)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Sign Up Tab
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selectedIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selectedIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selectedIndex == 1 ? FontWeight.w700 : FontWeight.w600,
                      color: selectedIndex == 1
                          ? const Color(0xFF133838)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
