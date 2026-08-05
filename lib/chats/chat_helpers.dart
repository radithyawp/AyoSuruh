import 'package:intl/intl.dart';

const List<String> _shortDays = <String>[
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];

const List<String> _longDays = <String>[
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const List<String> _months = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

DateTime? parseChatDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

String chatListTime(dynamic value) {
  final DateTime? date = parseChatDate(value);
  if (date == null) return '';

  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime messageDay = DateTime(date.year, date.month, date.day);
  final int difference = today.difference(messageDay).inDays;

  if (difference == 0) return DateFormat('HH:mm').format(date);
  if (difference == 1) return 'Kemarin';
  if (difference < 7) return _shortDays[date.weekday - 1];
  return DateFormat('dd/MM/yy').format(date);
}

String chatBubbleTime(dynamic value) {
  final DateTime? date = parseChatDate(value);
  if (date == null) return '';
  return DateFormat('HH:mm').format(date);
}

String chatDayLabel(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(date.year, date.month, date.day);
  final int difference = today.difference(day).inDays;

  if (difference == 0) return 'Hari ini';
  if (difference == 1) return 'Kemarin';
  return '${_longDays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} ${date.year}';
}

bool isSameChatDay(dynamic first, dynamic second) {
  final DateTime? a = parseChatDate(first);
  final DateTime? b = parseChatDate(second);
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
