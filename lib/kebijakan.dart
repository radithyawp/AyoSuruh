import 'package:flutter/material.dart';

import 'help_center.dart';
import 'widgets/home_shortcut_button.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import './theme/ayo_theme.dart';

class KebijakanPage extends StatelessWidget {
  const KebijakanPage({super.key});

  static Color get _primaryBrown => AyoAdaptiveColors.brown;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _primaryBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: AyoText(
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : const Color(0xFFFFE7C1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
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
                      AyoText(
                        'Privasi pengguna adalah bagian dari layanan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _primaryBrown,
                        ),
                      ),
                      SizedBox(height: 5),
                      AyoText(
                        AyoI18n.isEnglish ? 'Last updated: 13 August 2026.' : 'Pembaruan terakhir: 13 Agustus 2026.',
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
          _PrivacySection(
            number: '1',
            title: AyoI18n.isEnglish ? 'Data We Collect' : 'Data yang Kami Kumpulkan',
            body: AyoI18n.isEnglish
                ? 'Ayo Suruh may process your name, email, phone number, profile address, profile photo, authentication data, and other information you provide while using the app. For Partner applicants in the current UPI-student scope, verification data includes a UPI Student Card (KTM) to confirm student eligibility, a selected legal photo ID such as KTP, SIM, Passport, KITAS/KITAP, or another valid photo identity document, and a verification selfie taken with the front camera. These documents are used for manual administrative verification; this flow does not perform automated facial recognition.'
                : 'Ayo Suruh dapat memproses nama, email, nomor telepon, alamat profil, foto profil, data autentikasi, serta informasi lain yang Anda berikan ketika menggunakan aplikasi. Untuk calon Mitra dalam cakupan mahasiswa UPI saat ini, data verifikasi mencakup KTM UPI untuk memastikan status mahasiswa, identitas legal berfoto yang dipilih seperti KTP, SIM, Paspor, KITAS/KITAP, atau identitas sah lain, serta selfie verifikasi yang diambil dengan kamera depan. Dokumen tersebut digunakan untuk pemeriksaan administratif secara manual; alur ini tidak menggunakan pengenalan wajah otomatis.',
          ),
          const _PrivacySection(
            number: '2',
            title: 'Lokasi dan Data Pekerjaan',
            body:
                'Ketika Anda membuat atau menjalankan pekerjaan, kami dapat memproses alamat tujuan, koordinat lokasi yang dipilih, kategori, deskripsi, jadwal, penawaran, status pekerjaan, serta data terkait agar customer dan mitra dapat menjalankan layanan secara tepat.',
          ),
          _PrivacySection(
            number: '3',
            title: AyoI18n.isEnglish
                ? 'Authentication and Phone Confirmation'
                : 'Autentikasi dan Konfirmasi Nomor HP',
            body: AyoI18n.isEnglish
                ? 'Sign-in may use email/password or an identity provider such as Google through Supabase Auth. Ayo Suruh does not store plaintext passwords. On supported Android devices, Phone Number Hint may display SIM-based phone numbers so the user can select a number without granting SMS-reading permission. A number selected through this flow is recorded as confirmed from the device, not as SMS-verified and not as legal identity proof. Manually entered numbers remain marked unconfirmed until a supported confirmation method is completed.'
                : 'Login dapat menggunakan email/password atau penyedia identitas seperti Google melalui Supabase Auth. Ayo Suruh tidak menyimpan password mentah. Pada perangkat Android yang mendukung, Phone Number Hint dapat menampilkan nomor berbasis SIM agar pengguna dapat memilih nomor tanpa memberikan izin membaca SMS. Nomor yang dipilih melalui alur ini dicatat sebagai dikonfirmasi dari perangkat, bukan terverifikasi lewat SMS dan bukan bukti identitas hukum. Nomor yang diketik manual tetap ditandai belum dikonfirmasi sampai metode konfirmasi yang didukung diselesaikan.',
          ),
          const _PrivacySection(
            number: '4',
            title: 'Pembayaran, Refund, dan Dompet Mitra',
            body:
                'Untuk transaksi, kami dapat menyimpan nilai jasa, status pembayaran, identitas transaksi, metode pembayaran, refund, komisi platform, saldo ledger mitra, rekening pencairan, dan status payout. Data sensitif pembayaran diproses melalui penyedia payment gateway dan tidak dimaksudkan untuk menyimpan detail kartu secara langsung di Ayo Suruh.',
          ),
          _PrivacySection(
            number: '5',
            title: AyoI18n.isEnglish
                ? 'Chat, Voice Calls, and Support'
                : 'Chat, Panggilan Suara, dan Dukungan',
            body: AyoI18n.isEnglish
                ? 'Messages sent through chat and information provided to Support may be processed to operate jobs, resolve issues, prevent abuse, and improve service quality. For an active in-app voice call, microphone audio is transmitted in real time through LiveKit so the Customer and Partner can communicate. Ayo Suruh does not enable call recording or transcription in this feature, and phone numbers are not exposed through the in-app call flow.'
                : 'Pesan yang dikirim melalui chat dan informasi yang diberikan kepada Pusat Dukungan dapat diproses untuk menjalankan pekerjaan, menyelesaikan kendala, mencegah penyalahgunaan, dan meningkatkan kualitas layanan. Saat panggilan suara in-app aktif, audio mikrofon ditransmisikan secara real-time melalui LiveKit agar Customer dan Mitra dapat berkomunikasi. Ayo Suruh tidak mengaktifkan perekaman atau transkripsi pada fitur panggilan ini, dan nomor telepon tidak ditampilkan melalui alur panggilan in-app.',
          ),
          _PrivacySection(
            number: '6',
            title: 'Tujuan Penggunaan Data',
            body: AyoI18n.isEnglish
                ? 'Data is used to provide app features, match Customer needs with Partners, process transactions, verify accounts and current UPI-student Partner eligibility, display history, improve security, provide support, evaluate the product, and meet relevant operational needs. Verification documents are used only for the stated verification purpose and access should be limited to authorized administrative review.'
                : 'Data digunakan untuk menyediakan fitur aplikasi, mencocokkan kebutuhan Customer dengan Mitra, memproses transaksi, memverifikasi akun dan eligibility Mitra sebagai mahasiswa UPI pada cakupan saat ini, menampilkan riwayat, meningkatkan keamanan, memberi dukungan, melakukan evaluasi produk, dan memenuhi kebutuhan operasional yang relevan. Dokumen verifikasi digunakan untuk tujuan verifikasi yang telah dijelaskan dan aksesnya dibatasi untuk pemeriksaan administratif yang berwenang.',
          ),
          _PrivacySection(
            number: '7',
            title: AyoI18n.isEnglish
                ? 'Third Parties Supporting the Service'
                : 'Pihak Ketiga yang Mendukung Layanan',
            body: AyoI18n.isEnglish
                ? 'Ayo Suruh may use third-party services including Supabase for authentication/database, Midtrans for payment processing, Google for authentication and device-based Phone Number Hint, OpenStreetMap for maps/geolocation, and LiveKit for real-time in-app voice transport. Each provider may apply its own privacy and security policies.'
                : 'Ayo Suruh dapat menggunakan layanan pihak ketiga seperti Supabase untuk autentikasi/database, Midtrans untuk payment gateway, Google untuk autentikasi dan Phone Number Hint berbasis perangkat, OpenStreetMap untuk peta/geolokasi, serta LiveKit untuk transport audio panggilan in-app secara real-time. Masing-masing penyedia dapat menerapkan kebijakan privasi dan keamanannya sendiri.',
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
                'Pengguna dapat memperbarui data profil tertentu, mengubah password, mengatur izin perangkat, serta menggunakan menu Pengaturan > Kelola / Hapus Akun untuk menonaktifkan atau menghapus akun. Penghapusan dapat ditahan sementara ketika masih ada pekerjaan aktif, refund/dispute, pencairan, saldo mitra, kewajiban kontraktual, keamanan, atau kebutuhan pencatatan transaksi yang sah. Data historis tertentu dapat dipertahankan dalam bentuk yang dianonimkan apabila diperlukan untuk integritas transaksi.',
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : const Color(0xFFE7F1DE),
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
                const AyoText(
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
                  child: const AyoText('Hubungi Kami'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AyoText(
            AyoI18n.isEnglish ? 'This policy may be updated to reflect changes in services, security, regulations, or third-party providers. Material changes will be announced through the app or Ayo Suruh official channels.' : 'Kebijakan ini dapat diperbarui untuk menyesuaikan perubahan layanan, keamanan, regulasi, atau mitra pihak ketiga. Perubahan material akan diinformasikan melalui aplikasi atau kanal resmi Ayo Suruh.',
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
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : const Color(0xFFFFE7C1),
              shape: BoxShape.circle,
            ),
            child: AyoText(
              number,
              style: TextStyle(
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
                AyoText(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3E342E),
                  ),
                ),
                const SizedBox(height: 5),
                AyoText(
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
