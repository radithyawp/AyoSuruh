import 'package:flutter/material.dart';

import 'help_center.dart';
import 'widgets/home_shortcut_button.dart';

class KebijakanPage extends StatelessWidget {
  const KebijakanPage({super.key});

  static const Color _primaryBrown = Color(0xFF8B5A2B);
  static const Color _bg = Color(0xFFFAF6F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _primaryBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kebijakan Privasi',
          style: TextStyle(
            color: _primaryBrown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7C1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.privacy_tip_outlined,
                  color: _primaryBrown,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Privasi pengguna adalah bagian dari layanan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _primaryBrown,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Pembaruan: 7 Agustus 2026 · Berlaku untuk MVP Ayo Suruh.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF765638),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _PrivacySection(
            number: '1',
            title: 'Data yang Kami Kumpulkan',
            body:
                'Ayo Suruh dapat memproses nama, email, nomor telepon, alamat profil, foto profil, data autentikasi, serta informasi lain yang Anda berikan ketika menggunakan aplikasi. Untuk calon mitra, data dapat mencakup selfie dan dokumen pendaftaran yang diperlukan untuk proses verifikasi.',
          ),
          const _PrivacySection(
            number: '2',
            title: 'Lokasi dan Data Pekerjaan',
            body:
                'Ketika Anda membuat atau menjalankan pekerjaan, kami dapat memproses alamat tujuan, koordinat lokasi yang dipilih, kategori, deskripsi, jadwal, penawaran, status pekerjaan, serta data terkait agar customer dan mitra dapat menjalankan layanan secara tepat.',
          ),
          const _PrivacySection(
            number: '3',
            title: 'Autentikasi dan Akun Google',
            body:
                'Login dapat menggunakan email/password atau penyedia identitas seperti Google melalui Supabase Auth. Ayo Suruh tidak menyimpan password mentah. Fitur Ingat Saya mempertahankan preferensi sesi dan email, sedangkan penyimpanan kredensial dapat ditangani oleh password manager atau autofill bawaan perangkat.',
          ),
          const _PrivacySection(
            number: '4',
            title: 'Pembayaran, Refund, dan Dompet Mitra',
            body:
                'Untuk transaksi, kami dapat menyimpan nilai jasa, status pembayaran, identitas transaksi, metode pembayaran, refund, komisi platform, saldo ledger mitra, rekening pencairan, dan status payout. Data sensitif pembayaran diproses melalui penyedia payment gateway dan tidak dimaksudkan untuk menyimpan detail kartu secara langsung di Ayo Suruh.',
          ),
          const _PrivacySection(
            number: '5',
            title: 'Chat dan Dukungan',
            body:
                'Pesan yang dikirim melalui fitur chat dan informasi yang diberikan kepada Pusat Dukungan dapat diproses untuk menjalankan pekerjaan, menyelesaikan kendala, mencegah penyalahgunaan, dan meningkatkan kualitas layanan.',
          ),
          const _PrivacySection(
            number: '6',
            title: 'Tujuan Penggunaan Data',
            body:
                'Data digunakan untuk menyediakan fitur aplikasi, mencocokkan kebutuhan customer dengan mitra, memproses transaksi, memverifikasi akun, menampilkan riwayat, meningkatkan keamanan, memberi dukungan, melakukan evaluasi produk, dan memenuhi kebutuhan operasional yang relevan.',
          ),
          const _PrivacySection(
            number: '7',
            title: 'Pihak Ketiga yang Mendukung Layanan',
            body:
                'Ayo Suruh dapat menggunakan layanan pihak ketiga seperti Supabase untuk autentikasi/database, Midtrans untuk payment gateway, Google untuk autentikasi, OpenStreetMap untuk peta/geolokasi, dan layanan sistem lain yang diperlukan. Masing-masing penyedia dapat menerapkan kebijakan privasinya sendiri.',
          ),
          const _PrivacySection(
            number: '8',
            title: 'Penyimpanan dan Keamanan',
            body:
                'Kami menerapkan kontrol akses dan mekanisme keamanan yang tersedia pada layanan backend untuk membatasi akses data. Tidak ada sistem yang sepenuhnya bebas risiko, sehingga pengguna juga wajib menjaga keamanan akun, perangkat, dan kredensialnya.',
          ),
          const _PrivacySection(
            number: '9',
            title: 'Pilihan dan Hak Pengguna',
            body:
                'Pengguna dapat memperbarui data profil tertentu, mengubah password, mengatur izin perangkat, dan menghubungi Pusat Dukungan terkait koreksi atau penghapusan data. Permintaan dapat ditinjau dengan mempertimbangkan transaksi yang masih aktif, kewajiban kontraktual mitra, keamanan, dan kebutuhan pencatatan yang sah.',
          ),
          const _PrivacySection(
            number: '10',
            title: 'Perubahan Kebijakan',
            body:
                'Kebijakan ini dapat diperbarui seiring pengembangan Ayo Suruh, perubahan fitur, atau kebutuhan operasional. Versi terbaru akan ditampilkan melalui aplikasi atau kanal resmi Ayo Suruh.',
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F1DE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.support_agent_rounded,
                  color: Color(0xFF536E44),
                  size: 30,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ada pertanyaan tentang data atau privasi?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const HelpPage()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF536E44),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Hubungi Kami'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Catatan: kebijakan ini disusun untuk kebutuhan MVP dan tugas kewirausahaan. Sebelum peluncuran komersial penuh, dokumen legal perlu ditinjau kembali sesuai badan usaha, yurisdiksi, dan proses operasional yang berlaku.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: Color(0xFF7C716A),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE7C1),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: KebijakanPage._primaryBrown,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3E342E),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 12.2,
                    height: 1.5,
                    color: Color(0xFF6B605A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
