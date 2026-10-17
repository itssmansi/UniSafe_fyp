import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/unisafe_theme.dart';

class RoundedInputField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final String? Function(String?)? validator;
  final bool suffixIcon;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool isHalfWidth;

  const RoundedInputField({
    super.key,
    required this.labelText,
    required this.hintText,
    this.validator,
    this.suffixIcon = false,
    this.obscureText = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.prefixText,
    this.inputFormatters,
    this.maxLength,
    this.isHalfWidth = false,
  });

  @override
  State<RoundedInputField> createState() => _RoundedInputFieldState();
}

class _RoundedInputFieldState extends State<RoundedInputField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isHalfWidth ? 0 : 24,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.labelText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: UniSafeColors.ink,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.controller,
            obscureText: (widget.obscureText && _obscureText),
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            validator: widget.validator,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            buildCounter: widget.maxLength != null
                ? (_, {required currentLength, required isFocused, maxLength}) => null
                : null,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: UniSafeColors.ink,
            ),
            decoration: InputDecoration(
              isDense: false,
              filled: true,
              fillColor: Colors.white,
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                fontSize: 14.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
              prefixText: widget.prefixText,
              prefixStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: UniSafeColors.navy,
              ),
              suffixIcon: widget.suffixIcon
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 22,
                      ),
                      padding: const EdgeInsets.only(right: 12),
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: UniSafeColors.line, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: UniSafeColors.blue, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
