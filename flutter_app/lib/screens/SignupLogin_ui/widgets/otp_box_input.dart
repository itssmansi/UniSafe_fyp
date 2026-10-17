import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpBoxInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final TextEditingController? controller;

  const OtpBoxInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.controller,
  });

  @override
  State<OtpBoxInput> createState() => _OtpBoxInputState();
}

class _OtpBoxInputState extends State<OtpBoxInput> {
  late List<TextEditingController> _boxControllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _boxControllers = List.generate(widget.length, (index) => TextEditingController());
    _focusNodes = List.generate(widget.length, (index) => FocusNode());

    if (widget.controller != null) {
      widget.controller!.addListener(_handleExternalControllerChange);
      _syncFromExternalController();
    }
  }

  @override
  void didUpdateWidget(covariant OtpBoxInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleExternalControllerChange);
      widget.controller?.addListener(_handleExternalControllerChange);
      _syncFromExternalController();
    }
  }

  void _handleExternalControllerChange() {
    _syncFromExternalController();
  }

  void _syncFromExternalController() {
    final text = widget.controller?.text ?? '';
    for (int i = 0; i < widget.length; i++) {
      final char = i < text.length ? text[i] : '';
      if (_boxControllers[i].text != char) {
        _boxControllers[i].text = char;
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleExternalControllerChange);
    for (final c in _boxControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode {
    return _boxControllers.map((c) => c.text).join();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handles pasted text
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < widget.length; i++) {
        if (i < digits.length) {
          _boxControllers[i].text = digits[i];
        } else {
          _boxControllers[i].text = '';
        }
      }
      final focusIndex = digits.length < widget.length ? digits.length : widget.length - 1;
      _focusNodes[focusIndex].requestFocus();
    } else if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final code = _currentCode;
    if (widget.controller != null && widget.controller!.text != code) {
      widget.controller!.text = code;
    }
    widget.onChanged(code);
    if (code.length == widget.length && widget.onCompleted != null) {
      widget.onCompleted!(code);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double boxWidth = widget.length > 6 ? 35.0 : 44.0;
    final double boxHeight = widget.length > 6 ? 48.0 : 52.0;
    final double boxMargin = widget.length > 6 ? 2.5 : 4.0;
    final double fontSize = widget.length > 6 ? 17.0 : 20.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        final isFocused = _focusNodes[index].hasFocus;
        final hasValue = _boxControllers[index].text.isNotEmpty;

        return Container(
          width: boxWidth,
          height: boxHeight,
          margin: EdgeInsets.symmetric(horizontal: boxMargin),
          decoration: BoxDecoration(
            color: isFocused ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFF0B3B68)
                  : hasValue
                      ? const Color(0xFF64748B)
                      : const Color(0xFFCBD5E1),
              width: isFocused ? 2 : 1.2,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF0B3B68).withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace &&
                    _boxControllers[index].text.isEmpty &&
                    index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
              },
              child: TextFormField(
                controller: _boxControllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B3B68),
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(widget.length),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) => _onDigitChanged(index, val),
              ),
            ),
          ),
        );
      }),
    );
  }
}
