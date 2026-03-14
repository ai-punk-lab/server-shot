import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/server_profile.dart';
import '../models/service_definition.dart';
import '../providers/app_provider.dart';
import '../services/service_registry.dart';
import '../services/ssh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/service_chip.dart';
import 'credentials_screen.dart';
import 'deploy_screen.dart';

class ServerSetupScreen extends StatefulWidget {
  final ServerProfile? existingProfile;

  const ServerSetupScreen({super.key, this.existingProfile});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Connection fields
  late TextEditingController _nameCtrl;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;

  // SSH key
  String? _privateKey;

  // Deploy user fields
  bool _createUser = false;
  late TextEditingController _deployUserCtrl;
  late TextEditingController _deployPassCtrl;
  bool _deploySudo = true;
  bool _deploySudoNoPassword = true;

  // Custom SSH users
  List<Map<String, String>> _sshUsers = [];

  // Selected services
  Set<String> _selectedServices = {};

  // Credentials
  Map<String, Map<String, String>> _credentials = {};

  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _hostCtrl = TextEditingController(text: p?.host ?? '');
    _portCtrl = TextEditingController(text: (p?.port ?? 22).toString());
    _userCtrl = TextEditingController(text: p?.username ?? '');
    _passCtrl = TextEditingController(text: p?.password ?? '');
    _deployUserCtrl = TextEditingController(text: p?.deployUsername ?? '');
    _deployPassCtrl = TextEditingController(text: p?.deployPassword ?? '');
    _createUser = p?.createUser ?? false;
    _deploySudo = p?.deploySudo ?? true;
    _deploySudoNoPassword = p?.deploySudoNoPassword ?? true;
    _privateKey = p?.privateKey;
    _sshUsers = p?.sshUsers.map((u) => Map<String, String>.from(u)).toList() ?? [];
    _selectedServices = Set.from(p?.selectedServices ?? []);
    _credentials = Map.from(p?.credentials ?? {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _deployUserCtrl.dispose();
    _deployPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingProfile != null ? 'Edit Server' : 'New Server',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Page indicators
          _buildPageIndicator(),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildConnectionPage(),
                _buildServicesPage(),
                _buildReviewPage(),
              ],
            ),
          ),

          // Bottom nav
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == _currentPage;
          final isDone = i < _currentPage;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isDone
                          ? AppTheme.seedColor
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppTheme.seedColor
                        : isActive
                            ? AppTheme.seedColor.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: isActive || isDone
                          ? AppTheme.seedColor
                          : Colors.white.withValues(alpha: 0.1),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppTheme.seedColor
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                  ),
                ),
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isDone
                          ? AppTheme.seedColor
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildConnectionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Server Connection',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your server SSH details',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 28),

          _buildTextField(_nameCtrl, 'Profile Name', Icons.label_rounded,
              hint: 'My Dev Server'),
          const SizedBox(height: 16),
          _buildTextField(_hostCtrl, 'Host / IP', Icons.dns_rounded,
              hint: '192.168.1.100 or myserver.com'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(_userCtrl, 'Username', Icons.person_rounded,
                    hint: 'root'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(_portCtrl, 'Port', Icons.tag_rounded,
                    hint: '22', keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(_passCtrl, 'Password', Icons.lock_rounded,
              hint: '••••••••', obscure: true),
          const SizedBox(height: 12),
          // SSH Key toggle
          GestureDetector(
            onTap: () => _showSSHKeyDialog(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF16162B),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.vpn_key_rounded,
                      size: 18, color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _privateKey != null && _privateKey!.isNotEmpty
                          ? 'SSH Key configured'
                          : 'Add SSH Private Key (optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: _privateKey != null && _privateKey!.isNotEmpty
                            ? AppTheme.successColor
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  if (_privateKey != null && _privateKey!.isNotEmpty)
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: AppTheme.successColor)
                  else
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.white.withValues(alpha: 0.2)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Test connection button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.seedColor.withValues(alpha: 0.5),
                      ),
                    )
                  : Icon(
                      _testSuccess ? Icons.check_circle_rounded : Icons.wifi_tethering_rounded,
                      size: 18,
                    ),
              label: Text(_testing
                  ? 'Testing...'
                  : _testSuccess
                      ? 'Connection OK'
                      : 'Test Connection'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    _testSuccess ? AppTheme.successColor : AppTheme.seedColor,
                side: BorderSide(
                  color: _testSuccess ? AppTheme.successColor : AppTheme.seedColor,
                ),
              ),
            ),
          ),

          if (_testResult != null && !_testSuccess) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.errorColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.errorColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          Divider(color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 20),

          // Create user section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Deploy User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create a new user and deploy services under it',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _createUser,
                onChanged: (v) => setState(() => _createUser = v),
              ),
            ],
          ),

          if (_createUser) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppTheme.accentColor.withValues(alpha: 0.05),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_add_rounded,
                          color: AppTheme.accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'New User Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _deployUserCtrl,
                    'Username',
                    Icons.person_rounded,
                    hint: 'devuser',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    _deployPassCtrl,
                    'Password',
                    Icons.lock_rounded,
                    hint: 'Strong password for the new user',
                    obscure: true,
                  ),
                  const SizedBox(height: 16),
                  // Sudo toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sudo Access',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Add user to sudoers',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _deploySudo,
                        onChanged: (v) => setState(() {
                          _deploySudo = v;
                          if (!v) _deploySudoNoPassword = false;
                        }),
                      ),
                    ],
                  ),
                  if (_deploySudo) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Passwordless Sudo',
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              'sudo without entering password',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _deploySudoNoPassword,
                          onChanged: (v) =>
                              setState(() => _deploySudoNoPassword = v),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          Divider(color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 20),

          // SSH Users section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SSH Users',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                ],
              ),
              TextButton.icon(
                onPressed: _addSSHUser,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentColor,
                ),
              ),
            ],
          ),
          Text(
            'Extra users for quick terminal access',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          if (_sshUsers.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._sshUsers.asMap().entries.map((entry) {
              final i = entry.key;
              final user = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF16162B),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded,
                        size: 18, color: AppTheme.accentColor.withValues(alpha: 0.7)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            user['password']?.isNotEmpty == true ? '••••••••' : 'no password',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_rounded,
                          size: 16, color: Colors.white.withValues(alpha: 0.3)),
                      onPressed: () => _editSSHUser(i),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.errorColor.withValues(alpha: 0.5)),
                      onPressed: () => setState(() => _sshUsers.removeAt(i)),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 24),

          // Save without deploy
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saveOnly,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Server (without deploy)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.5),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addSSHUser() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add SSH User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              if (userCtrl.text.isNotEmpty) {
                setState(() {
                  _sshUsers.add({
                    'username': userCtrl.text,
                    'password': passCtrl.text,
                  });
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Add', style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }

  void _editSSHUser(int index) {
    final user = _sshUsers[index];
    final userCtrl = TextEditingController(text: user['username']);
    final passCtrl = TextEditingController(text: user['password']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit SSH User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              if (userCtrl.text.isNotEmpty) {
                setState(() {
                  _sshUsers[index] = {
                    'username': userCtrl.text,
                    'password': passCtrl.text,
                  };
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOnly() async {
    if (!_validateConnection()) return;
    final profile = _buildProfile();
    final provider = context.read<AppProvider>();
    await provider.updateProfile(profile);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server saved')),
    );
  }

  void _showSSHKeyDialog() {
    final keyCtrl = TextEditingController(text: _privateKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('SSH Private Key'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paste your private key (PEM format). Leave empty to use password auth.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                maxLines: 8,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_privateKey != null && _privateKey!.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _privateKey = null);
                Navigator.pop(ctx);
              },
              child: const Text('Remove',
                  style: TextStyle(color: Color(0xFFFF6B6B))),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _privateKey =
                    keyCtrl.text.isEmpty ? null : keyCtrl.text;
              });
              Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: AppTheme.seedColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _buildServicesPage() {
    final grouped = ServiceRegistry.grouped;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Services',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppTheme.seedColor.withValues(alpha: 0.15),
                ),
                child: Text(
                  '${_selectedServices.length} selected',
                  style: TextStyle(
                    color: AppTheme.seedColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose what to install on your server',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),

          // Quick presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Full Stack', [
                'docker', 'git', 'github_cli', 'nodejs', 'python', 'ruby',
                'neovim', 'zsh', 'tmux', 'postgresql', 'redis',
              ]),
              _buildPresetChip('Minimal', ['git', 'docker', 'nodejs', 'zsh']),
              _buildPresetChip('AI Dev', [
                'git', 'github_cli', 'nodejs', 'python', 'claude_code',
                'neovim', 'zsh', 'tmux', 'docker',
              ]),
              _buildPresetChip('Clear All', []),
            ],
          ),
          const SizedBox(height: 24),

          ...grouped.entries.map((entry) {
            final category = entry.key;
            final services = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      serviceCategoryIcon(category),
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      serviceCategoryLabel(category),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...services.map((service) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ServiceChip(
                        service: service,
                        selected: _selectedServices.contains(service.id),
                        onTap: () {
                          setState(() {
                            if (_selectedServices.contains(service.id)) {
                              _selectedServices.remove(service.id);
                            } else {
                              _selectedServices.add(service.id);
                            }
                          });
                        },
                      ),
                    )),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, List<String> ids) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFF1A1A2E),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      onPressed: () {
        setState(() {
          _selectedServices = Set.from(ids);
        });
      },
    );
  }

  Widget _buildReviewPage() {
    final resolved = ServiceRegistry.resolveDependencies(
        _selectedServices.toList());
    final servicesWithCreds = resolved
        .map((id) => ServiceRegistry.getById(id))
        .where((s) => s != null && s.credentialFields.isNotEmpty)
        .cast<ServiceDefinition>()
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review & Deploy',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Review your setup before deploying',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),

          // Server info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1A1A2E),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dns_rounded,
                        color: AppTheme.seedColor, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Server',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Name', _nameCtrl.text),
                _buildInfoRow(
                    'Host', '${_userCtrl.text}@${_hostCtrl.text}:${_portCtrl.text}'),
                if (_createUser && _deployUserCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Divider(color: Colors.white.withValues(alpha: 0.06)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_add_rounded,
                          color: AppTheme.accentColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'New user: ${_deployUserCtrl.text}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildInfoRow('Sudo', _deploySudo
                      ? (_deploySudoNoPassword ? 'Yes (no password)' : 'Yes (with password)')
                      : 'No'),
                  _buildInfoRow('Deploy as', _deployUserCtrl.text),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Services card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1A1A2E),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.apps_rounded,
                        color: AppTheme.accentColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${resolved.length} Services',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: resolved.map((id) {
                    final svc = ServiceRegistry.getById(id);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: (svc?.accentColor ?? AppTheme.seedColor)
                            .withValues(alpha: 0.12),
                      ),
                      child: Text(
                        '${svc?.iconChar ?? ''} ${svc?.name ?? id}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Credentials section
          if (servicesWithCreds.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1A1A2E),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.key_rounded,
                              color: AppTheme.warningColor, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Credentials',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _openCredentialsScreen,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Configure'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.seedColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...servicesWithCreds.map((svc) {
                    final creds = _credentials[svc.id] ?? {};
                    final configured = creds.values.any((v) => v.isNotEmpty);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            configured
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 16,
                            color: configured
                                ? AppTheme.successColor
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            svc.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            configured ? 'Configured' : 'Not set',
                            style: TextStyle(
                              fontSize: 12,
                              color: configured
                                  ? AppTheme.successColor.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Deploy button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _deploy,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.seedColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Deploy Now',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentPage > 0)
              TextButton.icon(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            const Spacer(),
            if (_currentPage < 2)
              ElevatedButton.icon(
                onPressed: _nextPage,
                icon: const Text('Next'),
                label: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage == 0 && !_validateConnection()) return;
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  bool _validateConnection() {
    if (_nameCtrl.text.isEmpty ||
        _hostCtrl.text.isEmpty ||
        _userCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return false;
    }
    return true;
  }

  Future<void> _testConnection() async {
    if (!_validateConnection()) return;
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = false;
    });

    final ssh = SSHService();
    final error = await ssh.testConnection(
      host: _hostCtrl.text,
      port: int.tryParse(_portCtrl.text) ?? 22,
      username: _userCtrl.text,
      password: _passCtrl.text,
      privateKey: _privateKey,
    );

    setState(() {
      _testing = false;
      _testResult = error;
      _testSuccess = error == null;
    });
  }

  void _openCredentialsScreen() async {
    final result = await Navigator.of(context).push<Map<String, Map<String, String>>>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CredentialsScreen(
          selectedServices: _selectedServices.toList(),
          currentCredentials: _credentials,
        ),
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
      ),
    );
    if (result != null) {
      setState(() => _credentials = result);
    }
  }

  ServerProfile _buildProfile() {
    return ServerProfile(
      id: widget.existingProfile?.id ?? const Uuid().v4(),
      name: _nameCtrl.text,
      host: _hostCtrl.text,
      port: int.tryParse(_portCtrl.text) ?? 22,
      username: _userCtrl.text,
      password: _passCtrl.text,
      privateKey: _privateKey,
      selectedServices: _selectedServices.toList(),
      credentials: _credentials,
      createUser: _createUser,
      deployUsername: _deployUserCtrl.text,
      deployPassword: _deployPassCtrl.text,
      deploySudo: _deploySudo,
      deploySudoNoPassword: _deploySudoNoPassword,
      sshUsers: _sshUsers,
      createdAt: widget.existingProfile?.createdAt,
    );
  }

  Future<void> _deploy() async {
    final profile = _buildProfile();

    // Save profile
    final provider = context.read<AppProvider>();
    await provider.updateProfile(profile);

    if (!mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DeployScreen(profile: profile),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
