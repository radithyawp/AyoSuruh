import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _pinFieldBrown = Color(0xFF8A5300);
const Color _pinFieldOrange = Color(0xFFF6990E);

class SixDigitPinField extends StatefulWidget {
  const SixDigitPinField({
    super.key,
    required this.controller,
    this.label,
    this.validator,
    this.errorText,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = true,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onCompleted,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? Function(String?)? validator;
  final String? errorText;
  final bool autofocus;
  final bool enabled;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SixDigitPinField> createState() => _SixDigitPinFieldState();
}

class _SixDigitPinFieldState extends State<SixDigitPinField> {
  final FocusNode _focusNode = FocusNode();
  FormFieldState<String>? _formFieldState;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SixDigitPinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _formFieldState?.didChange(widget.controller.text);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    final String value = widget.controller.text;
    if (_formFieldState?.value != value) {
      _formFieldState?.didChange(value);
    }
    if (mounted) setState(() {});
  }

  void _handleChanged(String value) {
    _formFieldState?.didChange(value);
    widget.onChanged?.call(value);

    if (value.length == 6) {
      widget.onCompleted?.call(value);
    }
  }

  void _requestFocus() {
    if (!widget.enabled) return;
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (FormFieldState<String> field) {
        _formFieldState = field;

        final String value = widget.controller.text;
        final String? effectiveError = widget.errorText ?? field.errorText;
        final bool focused = _focusNode.hasFocus;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.label != null) ...<Widget>[
              Text(
                widget.label!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _pinFieldBrown,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Semantics(
              label: widget.label ?? 'PIN 6 digit',
              textField: true,
              obscured: widget.obscureText,
              child: GestureDetector(
                onTap: _requestFocus,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  children: <Widget>[
                    Row(
                      children: List<Widget>.generate(6, (int index) {
                        final bool filled = index < value.length;
                        final bool active = focused &&
                            ((value.length < 6 && index == value.length) ||
                                (value.length == 6 && index == 5));

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == 5 ? 0 : 8,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFFFFF5E6)
                                    : const Color(0xFFFFFBF7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: effectiveError != null
                                      ? Colors.red.shade400
                                      : active
                                          ? _pinFieldOrange
                                          : filled
                                              ? const Color(0xFFF4B04A)
                                              : const Color(0xFFE9DDD6),
                                  width: active ? 1.8 : 1.1,
                                ),
                                boxShadow: active
                                    ? const <BoxShadow>[
                                        BoxShadow(
                                          color: Color(0x1AF6990E),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 100),
                                child: Text(
                                  filled
                                      ? (widget.obscureText
                                          ? '●'
                                          : value[index])
                                      : '',
                                  key: ValueKey<String>(
                                    '$index-${filled ? value[index] : ''}',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    color: _pinFieldBrown,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.01,
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          autofocus: widget.autofocus,
                          enabled: widget.enabled,
                          keyboardType: TextInputType.number,
                          textInputAction: widget.textInputAction,
                          showCursor: false,
                          enableSuggestions: false,
                          autocorrect: false,
                          maxLength: 6,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: _handleChanged,
                          onSubmitted: widget.onSubmitted,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (effectiveError != null) ...<Widget>[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  effectiveError,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
