import 'package:flutter/material.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep; // 0, 1, 2, 3
  final int totalSteps;
  final List<String> stepTitles;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
    this.stepTitles = const ['Details', 'Email OTP', 'Phone OTP', 'Aadhaar KYC'],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          // Step circles and connecting lines
          Row(
            children: List.generate(totalSteps * 2 - 1, (index) {
              if (index.isOdd) {
                // Connecting line
                final int stepBefore = index ~/ 2;
                final bool isCompleted = currentStep > stepBefore;
                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF133838)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              } else {
                // Step Circle
                final int stepIndex = index ~/ 2;
                final bool isCompleted = currentStep > stepIndex;
                final bool isCurrent = currentStep == stepIndex;

                Color bgColor;
                Color textColor;
                Widget content;

                if (isCompleted) {
                  bgColor = const Color(0xFF10B981);
                  textColor = Colors.white;
                  content = const Icon(Icons.check, size: 14, color: Colors.white);
                } else if (isCurrent) {
                  bgColor = const Color(0xFF133838);
                  textColor = Colors.white;
                  content = Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                } else {
                  bgColor = const Color(0xFFF1F5F9);
                  textColor = const Color(0xFF94A3B8);
                  content = Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFF133838)
                          : isCompleted
                              ? const Color(0xFF10B981)
                              : const Color(0xFFCBD5E1),
                      width: isCurrent ? 2 : 1.2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: const Color(0xFF133838).withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: content),
                );
              }
            }),
          ),
          const SizedBox(height: 10),

          // Current Step Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP ${currentStep + 1} OF $totalSteps',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF748288),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                stepTitles[currentStep.clamp(0, stepTitles.length - 1)],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF133838),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
