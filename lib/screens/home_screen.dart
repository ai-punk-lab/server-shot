import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/server_profile.dart';
import '../services/update_service.dart';
import '../widgets/gradient_card.dart';
import '../theme/app_theme.dart';
import 'server_setup_screen.dart';
import 'ssh_terminal_screen.dart';
import 'settings_screen.dart';
import 'server_monitor_screen.dart';
import 'sftp_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppUpdate? _availableUpdate;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update != null && mounted) {
      setState(() => _availableUpdate = update);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (!provider.initialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return CustomScrollView(
            slivers: [
              // Hero header
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/icon.png',
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ServerShot',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'Deploy your stack anywhere',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B6B80),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.settings_rounded,
                                  color: Colors.white.withValues(alpha: 0.3)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()),
                              ),
                            ),
                          ],
                        ),
                        if (_availableUpdate != null) ...[
                          const SizedBox(height: 16),
                          _buildUpdateBanner(),
                        ],
                        const SizedBox(height: 28),
                        if (provider.profiles.isEmpty) ...[
                          _buildEmptyState(context),
                        ] else ...[
                          Text(
                            'SERVERS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Server list
              if (provider.profiles.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final profile = provider.profiles[index];
                      return _buildServerCard(context, profile, provider);
                    },
                    childCount: provider.profiles.length,
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToSetup(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Server'),
        backgroundColor: AppTheme.seedColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  Widget _buildUpdateBanner() {
    final update = _availableUpdate!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            AppTheme.seedColor.withValues(alpha: 0.15),
            AppTheme.accentColor.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppTheme.seedColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_rounded,
                  color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Update available: v${update.version}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _availableUpdate = null),
                child: Icon(Icons.close_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => UpdateService.downloadAndInstall(
                      update.downloadUrl),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.seedColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: UpdateService.openReleasePage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.5),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                ),
                child: const Text('Notes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.seedColor.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.dns_rounded,
                size: 44,
                color: AppTheme.seedColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No servers yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first server and deploy\nyour entire dev stack in one tap',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.4),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => _navigateToSetup(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Server'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(
      BuildContext context, ServerProfile profile, AppProvider provider) {
    return GradientCard(
      accentColor: AppTheme.seedColor,
      onLongPress: () => _showDeleteDialog(context, profile, provider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.seedColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  color: AppTheme.seedColor.withValues(alpha: 0.8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.username}@${profile.host}:${profile.port}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (profile.selectedServices.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${profile.selectedServices.length} services configured',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.accentColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Bottom row: action buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.terminal_rounded,
                  label: 'Terminal',
                  color: AppTheme.accentColor,
                  onTap: () => _openTerminal(context, profile),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.folder_rounded,
                  label: 'Files',
                  color: AppTheme.warningColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SftpScreen(profile: profile),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.monitor_heart_rounded,
                  label: 'Monitor',
                  color: AppTheme.successColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServerMonitorScreen(profile: profile),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.rocket_launch_rounded,
                  label: 'Deploy',
                  color: AppTheme.seedColor,
                  onTap: () => _navigateToSetup(context, profile: profile),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: Colors.white.withValues(alpha: 0.4),
                  onTap: () => _navigateToSetup(context, profile: profile),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.1),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTerminal(BuildContext context, ServerProfile profile) {
    // Collect all available users
    final hasDeployUser = profile.createUser &&
        profile.deployUsername != null &&
        profile.deployUsername!.isNotEmpty;
    final hasCustomUsers = profile.sshUsers.isNotEmpty;

    // If only SSH login user — go straight
    if (!hasDeployUser && !hasCustomUsers) {
      _launchTerminal(context, profile);
      return;
    }

    // Show user picker
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connect as',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose which user to open terminal with',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            // SSH login user
            _userOption(
              ctx,
              profile: profile,
              username: profile.username,
              label: '${profile.username} (SSH login)',
              icon: Icons.admin_panel_settings_rounded,
              color: AppTheme.warningColor,
            ),
            // Deploy user
            if (hasDeployUser) ...[
              const SizedBox(height: 10),
              _userOption(
                ctx,
                profile: profile,
                username: profile.deployUsername!,
                password: profile.deployPassword,
                label: '${profile.deployUsername} (deploy user)',
                icon: Icons.engineering_rounded,
                color: AppTheme.accentColor,
              ),
            ],
            // Custom SSH users
            ...profile.sshUsers.map((user) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _userOption(
                  ctx,
                  profile: profile,
                  username: user['username'] ?? '',
                  password: user['password'],
                  label: user['username'] ?? '',
                  icon: Icons.person_rounded,
                  color: AppTheme.seedColor,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _userOption(
    BuildContext ctx, {
    required ServerProfile profile,
    required String username,
    String? password,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        final termProfile = ServerProfile(
          id: profile.id,
          name: profile.name,
          host: profile.host,
          port: profile.port,
          username: username,
          password: password ?? profile.password,
        );
        _launchTerminal(ctx, termProfile);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_rounded,
              color: color.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _launchTerminal(BuildContext context, ServerProfile profile) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SSHTerminalScreen(profile: profile),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _navigateToSetup(BuildContext context, {ServerProfile? profile}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ServerSetupScreen(existingProfile: profile),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, ServerProfile profile, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Server'),
        content: Text('Delete "${profile.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              provider.deleteProfile(profile.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
  }
}
