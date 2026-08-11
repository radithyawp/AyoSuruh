import 'package:flutter/services.dart';

class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter({this.maxValue = 10000000});

  final int maxValue;

  static int parse(String text) {
    final String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  static String format(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final int? parsed = int.tryParse(digits);
    if (parsed == null || parsed > maxValue) {
      return oldValue;
    }

    final String formatted = format(parsed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
