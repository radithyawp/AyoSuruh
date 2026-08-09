import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/home_shortcut_button.dart';

class MitraContractPage extends StatelessWidget {
  const MitraContractPage({
    super.key,
    required this.contract,
  });

  final Map<String, dynamic> contract;

  static const Color _brown = Color(0xFF8B5A2B);
  static const Color _bg = Color(0xFFFCF8FC);

  @override
  Widget build(BuildContext context) {
    final String title = (contract['title'] ?? 'Kontrak Kemitraan Ayo Suruh')
        .toString();
    final String version = (contract['version'] ?? '-').toString();
    final String content = (contract['content'] ?? '').toString().trim();
    final DateTime? effectiveAt = DateTime.tryParse(
      contract['effective_at']?.toString() ?? '',
    )?.toLocal();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _brown),
        ),
        title: const Text(
          'Kontrak / MoU Mitra',
          style: TextStyle(color: _brown, fontWeight: FontWeight.w800),
        ),
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9CA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: _brown,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(label: Text('Versi $version')),
                    if (effectiveAt != null)
                      Chip(
                        label: Text(
                          'Berlaku ${DateFormat('dd MMM yyyy').format(effectiveAt)}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8DED8)),
            ),
            child: SelectableText(
              content.isEmpty
                  ? 'Isi kontrak belum tersedia. Jangan kirim pengajuan sebelum kontrak dapat dibaca.'
                  : content,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: Color(0xFF514740),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Persetujuan dicatat berdasarkan versi kontrak dan waktu saat pengajuan dikirim. Jika kontrak aktif berubah, aplikasi dapat meminta persetujuan ulang.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Color(0xFF746A64),
            ),
          ),
        ],
      ),
    );
  }
}
