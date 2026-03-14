import 'dart:async';
import 'package:flutter/material.dart';
import '../models/server_profile.dart';
import '../services/ssh_service.dart';
import '../theme/app_theme.dart';

class ServerMonitorScreen extends StatefulWidget {
  final ServerProfile profile;

  const ServerMonitorScreen({super.key, required this.profile});

  @override
  State<ServerMonitorScreen> createState() => _ServerMonitorScreenState();
}

class _ServerMonitorScreenState extends State<ServerMonitorScreen> {
  final SSHService _ssh = SSHService();
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // Parsed stats
  String _hostname = '';
  String _uptime = '';
  String _os = '';
  double _cpuUsage = 0;
  double _memUsed = 0;
  double _memTotal = 0;
  double _diskUsed = 0;
  double _diskTotal = 0;
  int _processes = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await _ssh.connect(
      host: widget.profile.host,
      port: widget.profile.port,
      username: widget.profile.username,
      password: widget.profile.password,
      privateKey: widget.profile.privateKey,
    );

    if (!ok) {
      setState(() {
        _loading = false;
        _error = _ssh.lastError ?? 'Connection failed';
      });
      return;
    }

    await _fetchStats();

    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_ssh.isConnected) _fetchStats();
    });
  }

  Future<void> _fetchStats() async {
    try {
      final result = await _ssh.execute('''
echo "HOSTNAME:\$(hostname)"
echo "UPTIME:\$(uptime -p 2>/dev/null || uptime)"
echo "OS:\$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || uname -s)"
echo "CPU:\$(top -bn1 2>/dev/null | grep 'Cpu(s)' | awk '{print \$2}' || echo 0)"
FREE=\$(free -m 2>/dev/null)
echo "MEM_USED:\$(echo "\$FREE" | awk '/Mem:/ {print \$3}')"
echo "MEM_TOTAL:\$(echo "\$FREE" | awk '/Mem:/ {print \$2}')"
DF=\$(df -BM / 2>/dev/null | tail -1)
echo "DISK_USED:\$(echo "\$DF" | awk '{print \$3}' | tr -d 'M')"
echo "DISK_TOTAL:\$(echo "\$DF" | awk '{print \$2}' | tr -d 'M')"
echo "PROCS:\$(ps aux 2>/dev/null | wc -l)"
''');

      for (final line in result.split('\n')) {
        final parts = line.split(':');
        if (parts.length < 2) continue;
        final key = parts[0].trim();
        final value = parts.sublist(1).join(':').trim();
        switch (key) {
          case 'HOSTNAME':
            _hostname = value;
            break;
          case 'UPTIME':
            _uptime = value;
            break;
          case 'OS':
            _os = value;
            break;
          case 'CPU':
            _cpuUsage = double.tryParse(value) ?? 0;
            break;
          case 'MEM_USED':
            _memUsed = double.tryParse(value) ?? 0;
            break;
          case 'MEM_TOTAL':
            _memTotal = double.tryParse(value) ?? 1;
            break;
          case 'DISK_USED':
            _diskUsed = double.tryParse(value) ?? 0;
            break;
          case 'DISK_TOTAL':
            _diskTotal = double.tryParse(value) ?? 1;
            break;
          case 'PROCS':
            _processes = int.tryParse(value) ?? 0;
            break;
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ssh.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Monitor')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          color: AppTheme.errorColor, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _connect, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchStats,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Server info
                      _infoCard(),
                      const SizedBox(height: 12),
                      // CPU
                      _gaugeCard(
                        'CPU',
                        Icons.memory_rounded,
                        _cpuUsage / 100,
                        '${_cpuUsage.toStringAsFixed(1)}%',
                        AppTheme.seedColor,
                      ),
                      const SizedBox(height: 12),
                      // Memory
                      _gaugeCard(
                        'Memory',
                        Icons.storage_rounded,
                        _memTotal > 0 ? _memUsed / _memTotal : 0,
                        '${_memUsed.toInt()} / ${_memTotal.toInt()} MB',
                        AppTheme.accentColor,
                      ),
                      const SizedBox(height: 12),
                      // Disk
                      _gaugeCard(
                        'Disk /',
                        Icons.disc_full_rounded,
                        _diskTotal > 0 ? _diskUsed / _diskTotal : 0,
                        '${(_diskUsed / 1024).toStringAsFixed(1)} / ${(_diskTotal / 1024).toStringAsFixed(1)} GB',
                        AppTheme.warningColor,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hostname,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _infoRow(Icons.computer_rounded, _os),
          _infoRow(Icons.schedule_rounded, _uptime),
          _infoRow(Icons.apps_rounded, '$_processes processes'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
          ),
        ],
      ),
    );
  }

  Widget _gaugeCard(
      String title, IconData icon, double value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              color: value > 0.9
                  ? AppTheme.errorColor
                  : value > 0.7
                      ? AppTheme.warningColor
                      : color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
