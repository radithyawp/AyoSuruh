import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'kebijakan.dart';
import 'syarat_ketentuan.dart';
import 'widgets/home_shortcut_button.dart';
import 'theme/ayo_theme.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class TentangAyoSuruhPage extends StatelessWidget {
  const TentangAyoSuruhPage({super.key});

  static Color get _brown => AyoAdaptiveColors.brown;

  Future<void> _openUrl(BuildContext context, String value) async {
    final Uri uri = Uri.parse(value);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AyoText('Tautan belum dapat dibuka.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AyoText('Gagal membuka aplikasi tujuan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _brown),
          onPressed: () => Navigator.pop(context),
        ),
        title: AyoText(
          'Tentang Ayo Suruh',
          style: TextStyle(
            color: _brown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: <Widget>[
          _buildAppLogoSection(context),
          const SizedBox(height: 20),
          _buildMissionCard(),
          const SizedBox(height: 14),
          _buildAyosMascotCard(context),
          const SizedBox(height: 14),
          _featureCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'Membantu Kebutuhan Harian',
            description:
                'Menghubungkan customer yang membutuhkan bantuan dengan mitra yang dapat menangani pekerjaan secara lebih cepat dan fleksibel.',
            background: const Color(0xFFF0F6EC),
          ),
          const SizedBox(height: 10),
          _featureCard(
            icon: Icons.groups_2_outlined,
            title: 'Membuka Peluang untuk Mitra',
            description:
                'Mitra dapat menemukan kebutuhan customer, menawarkan harga dan keterampilan, serta membangun reputasi melalui pekerjaan yang diselesaikan.',
            background: const Color(0xFFFFF1DF),
          ),
          const SizedBox(height: 10),
          _featureCard(
            icon: Icons.payments_outlined,
            title: 'Model Transaksi Transparan',
            description:
                'Ayo Suruh menggunakan platform commission 6% pada transaksi berhasil. Pembayaran, refund, dan pendapatan mitra dicatat sebagai bagian dari alur transaksi.',
            background: const Color(0xFFFFE9E3),
          ),
          const SizedBox(height: 22),
          const AyoText(
            'Kanal Resmi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _socialTile(
            context,
            icon: Icons.language_rounded,
            title: 'Website Company Profile',
            subtitle: 'madouseixalisphera.github.io/AyoSuruh-Web',
            onTap: () => _openUrl(
              context,
              'https://madouseixalisphera.github.io/AyoSuruh-Web/',
            ),
          ),
          _socialTile(
            context,
            assetPath: 'assets/images/instagram.png',
            icon: Icons.camera_alt_outlined,
            title: 'Instagram',
            subtitle: '@ayo.suruh',
            onTap: () => _openUrl(
              context,
              'https://www.instagram.com/ayo.suruh?igsh=MWF6Y2M3NTFyYzJreQ==',
            ),
          ),
          _socialTile(
            context,
            assetPath: 'assets/images/whatsapp.png',
            icon: Icons.chat_bubble_outline_rounded,
            title: 'WhatsApp Business',
            subtitle: '+62 889-5255-693',
            onTap: () => _openUrl(
              context,
              'https://wa.me/628895255693?text=Halo%20Ayo%20Suruh%2C%20saya%20ingin%20bertanya%20tentang%20layanan%20Ayo%20Suruh.',
            ),
          ),
          const SizedBox(height: 24),
          const AyoText(
            '© 2026 Ayo Suruh. Dikembangkan sebagai proyek kewirausahaan Teknik Komputer UPI Kampus Cibiru.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, height: 1.4, color: Color(0xFF776C65)),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SyaratKetentuanPage(),
                  ),
                ),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const AyoText('Ketentuan Layanan'),
              ),
              AyoText('•', style: TextStyle(color: _brown)),
              TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const KebijakanPage()),
                ),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const AyoText('Kebijakan Privasi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogoSection(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/logo_ayo_suruh_transparent.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 10),
        AyoText(
          'Ayo Suruh',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _brown,
          ),
        ),
        const SizedBox(height: 2),
        const AyoText(
          'Versi 1.0.0',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF776C65)),
        ),
      ],
    );
  }


  Widget _buildAyosMascotCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE1DA)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  'Siap bantu kebutuhan harianmu',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _brown,
                  ),
                ),
                const SizedBox(height: 6),
                AyoText(
                  'AYOS hadir sebagai maskot yang menemani pencarian jasa, percakapan, dan transaksi supaya pengalaman memakai Ayo Suruh terasa lebih ramah dan menyenangkan.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(
            'assets/images/ayos/ayos_hello.png',
            width: 94,
            height: 94,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFE4B4), Color(0xFFFFF2DE)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AyoText(
            'MISI KAMI',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
              color: _brown,
            ),
          ),
          SizedBox(height: 8),
          AyoText(
            'Ayo Suruh hadir sebagai platform jasa berbasis komunitas yang mempertemukan kebutuhan sehari-hari customer dengan kemampuan mitra lokal. Kami ingin membuat proses mencari bantuan, berkomunikasi, bertransaksi, dan menyelesaikan pekerjaan menjadi lebih praktis dalam satu aplikasi.',
            textAlign: TextAlign.justify,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF5F5148)),
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    IconData? icon,
    required String title,
    required String description,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _brown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                AyoText(
                  description,
                  style: const TextStyle(fontSize: 11.8, height: 1.4, color: Color(0xFF695D56)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialTile(
    BuildContext context, {
    IconData? icon,
    String? assetPath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFECE1DA)),
      ),
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: assetPath != null
            ? SizedBox(
                width: 28,
                height: 28,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  color: enabled ? null : Colors.grey,
                  colorBlendMode: enabled ? null : BlendMode.saturation,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    icon ?? Icons.open_in_new_rounded,
                    color: enabled ? _brown : Colors.grey,
                  ),
                ),
              )
            : Icon(icon, color: enabled ? _brown : Colors.grey),
        title: AyoText(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        subtitle: AyoText(
          subtitle,
          style: enabled
              ? AyoTypography.link(context).copyWith(fontSize: 11)
              : const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: Icon(
          enabled ? Icons.open_in_new_rounded : Icons.schedule_rounded,
          size: 17,
          color: enabled ? _brown : Colors.grey,
        ),
      ),
    );
  }
}
