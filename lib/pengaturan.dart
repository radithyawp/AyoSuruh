import 'package:ayosuruh/account/account_management_page.dart';
import 'package:ayosuruh/change_password.dart';
import 'package:ayosuruh/feedback/app_feedback_page.dart';
import 'package:ayosuruh/kebijakan.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import 'package:ayosuruh/notification_settings_page.dart';
import 'package:ayosuruh/security_settings_page.dart';
import 'package:ayosuruh/settings/app_settings.dart';
import 'package:ayosuruh/syarat_ketentuan.dart';
import 'package:ayosuruh/tentang_ayosuruh.dart';
import 'package:ayosuruh/tutorial/ayos_tutorial.dart';
import 'package:ayosuruh/widgets/home_shortcut_button.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  String _userName = 'Pengguna';
  String _userEmail = 'email@domain.com';
  String? _avatarUrl;
  bool _isLoading = true;

  AppSettingsController get _settings => AppSettingsController.instance;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      final User? currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        final Map<String, dynamic>? userData = await supabase
            .from('users')
            .select('fullname, avatar_url')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _userName = userData?['fullname']?.toString() ??
                currentUser.email?.split('@').first ??
                'Pengguna';
            _userEmail = currentUser.email ?? 'email@domain.com';
            _avatarUrl = userData?['avatar_url']?.toString();
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      debugPrint('Error loading user profile: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTutorialAgain() async {
    final String mode = (Supabase.instance.client.auth.currentUser
                ?.userMetadata?['active_mode'] ??
            'customer')
        .toString();
    await AyosTutorial.show(context, mode: mode);
  }

  Future<void> _showLanguagePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  'Bahasa Aplikasi',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                AyoText(
                  'Pilih bahasa yang digunakan di seluruh Ayo Suruh.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                _choiceTile<AyoLanguage>(
                  context: sheetContext,
                  value: AyoLanguage.indonesia,
                  selectedValue: _settings.language,
                  icon: Icons.language_rounded,
                  title: 'Indonesia',
                  subtitle: 'Bahasa Indonesia',
                  onSelected: (AyoLanguage value) async {
                    Navigator.pop(sheetContext);
                    await _settings.setLanguage(value);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                _choiceTile<AyoLanguage>(
                  context: sheetContext,
                  value: AyoLanguage.english,
                  selectedValue: _settings.language,
                  icon: Icons.translate_rounded,
                  title: 'English',
                  subtitle: 'English (US)',
                  onSelected: (AyoLanguage value) async {
                    Navigator.pop(sheetContext);
                    await _settings.setLanguage(value);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showThemePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  'Tema Aplikasi',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                AyoText(
                  'Pilih tampilan terang, gelap, atau ikuti pengaturan perangkat.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                _choiceTile<ThemeMode>(
                  context: sheetContext,
                  value: ThemeMode.system,
                  selectedValue: _settings.themeMode,
                  icon: Icons.brightness_auto_rounded,
                  title: 'Ikuti sistem',
                  subtitle: 'Menyesuaikan tampilan perangkat',
                  onSelected: _selectTheme,
                ),
                const SizedBox(height: 8),
                _choiceTile<ThemeMode>(
                  context: sheetContext,
                  value: ThemeMode.light,
                  selectedValue: _settings.themeMode,
                  icon: Icons.light_mode_outlined,
                  title: 'Mode Terang',
                  subtitle: 'Latar terang dan kontras hangat',
                  onSelected: _selectTheme,
                ),
                const SizedBox(height: 8),
                _choiceTile<ThemeMode>(
                  context: sheetContext,
                  value: ThemeMode.dark,
                  selectedValue: _settings.themeMode,
                  icon: Icons.dark_mode_outlined,
                  title: 'Mode Gelap',
                  subtitle: 'Nyaman digunakan di lingkungan redup',
                  onSelected: _selectTheme,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectTheme(ThemeMode value) async {
    Navigator.of(context).pop();
    await _settings.setThemeMode(value);
    if (mounted) setState(() {});
  }

  Widget _choiceTile<T>({
    required BuildContext context,
    required T value,
    required T selectedValue,
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function(T value) onSelected,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool selected = value == selectedValue;
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSelected(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AyoText(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AyoText(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey<String>('selected'),
                        color: theme.colorScheme.primary,
                      )
                    : const SizedBox(
                        key: ValueKey<String>('unselected'),
                        width: 24,
                        height: 24,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _languageLabel =>
      _settings.language == AyoLanguage.english ? 'English' : 'Indonesia';

  String get _themeLabel => switch (_settings.themeMode) {
        ThemeMode.light => 'Mode Terang',
        ThemeMode.dark => 'Mode Gelap',
        ThemeMode.system => 'Ikuti sistem',
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: AyoText('Pengaturan', style: theme.textTheme.titleLarge),
        titleSpacing: 0,
        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildProfileCard(theme),
                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, 'KEAMANAN'),
                  const SizedBox(height: 8),
                  _buildCardGroup(theme, <Widget>[
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.shield_outlined,
                      title: 'Keamanan Akun',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const SecuritySettingsPage(),
                        ),
                      ),
                    ),
                    _buildDivider(theme),
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.lock_outline,
                      title: 'Ganti Password',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const ChangePassword()),
                      ),
                    ),
                    _buildDivider(theme),
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.manage_accounts_outlined,
                      title: 'Kelola / Hapus Akun',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountManagementPage(),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSectionTitle(theme, 'PREFERENSI'),
                  const SizedBox(height: 8),
                  _buildCardGroup(theme, <Widget>[
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.language_rounded,
                      title: 'Bahasa',
                      subtitle: _languageLabel,
                      onTap: _showLanguagePicker,
                    ),
                    _buildDivider(theme),
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.contrast_rounded,
                      title: 'Tampilan',
                      subtitle: _themeLabel,
                      onTap: _showThemePicker,
                    ),
                    _buildDivider(theme),
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.notifications_none_outlined,
                      title: 'Pengaturan Notifikasi',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationSettingsPage(),
                        ),
                      ),
                    ),
                    _buildDivider(theme),
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.auto_awesome_outlined,
                      title: 'Tutorial Aplikasi',
                      onTap: _showTutorialAgain,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSectionTitle(theme, 'INFORMASI'),
                  const SizedBox(height: 8),
                  _buildCardGroup(theme, <Widget>[
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.rate_review_outlined,
                      title: 'Kritik & Saran',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AppFeedbackPage(),
                        ),
                      ),
                    ),
                    _buildDivider(theme),
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.description_outlined,
                      title: 'Syarat & Ketentuan',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const SyaratKetentuanPage()),
                      ),
                    ),
                    _buildDivider(theme),
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.verified_user_outlined,
                      title: 'Kebijakan Privasi',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const KebijakanPage()),
                      ),
                    ),
                    _buildDivider(theme),
                    _buildSettingTile(
                      theme: theme,
                      icon: Icons.info_outline,
                      title: 'Tentang Ayo Suruh',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const TentangAyoSuruhPage()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  Center(
                    child: AyoText(
                      'Versi 1.0.0 (Build 1)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 27,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                ? NetworkImage(_avatarUrl!)
                : null,
            child: _avatarUrl == null || _avatarUrl!.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(7),
                    child: Image.asset(
                      'assets/images/Logo_Ayo_Suruh.png',
                      fit: BoxFit.contain,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  _userName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                AyoText(
                  _userEmail,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return AyoText(
      title,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCardGroup(ThemeData theme, List<Widget> children) {
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AyoText(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    AyoText(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outlineVariant,
      indent: 66,
    );
  }
}
