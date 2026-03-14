import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/server_profile.dart';
import '../services/deployment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/terminal_view.dart';
import '../widgets/status_badge.dart';
import 'ssh_terminal_screen.dart';

class DeployScreen extends StatefulWidget {
  final ServerProfile profile;

  const DeployScreen({super.key, required this.profile});

  @override
  State<DeployScreen> createState() => _DeployScreenState();
}

class _DeployScreenState extends State<DeployScreen>
    with TickerProviderStateMixin {
  late DeploymentService _deploymentService;
  bool _showServiceList = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _deploymentService = DeploymentService();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start deployment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deploymentService.deploy(widget.profile);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _deploymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _deploymentService,
          builder: (context, _) {
            final state = _deploymentService.state;
            final isDone = state.overallStatus == DeploymentStatus.completed ||
                state.overallStatus == DeploymentStatus.failed;

            return SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(state, isDone),

                  // Progress bar
                  if (!isDone)
                    _buildProgressBar(state),

                  // Toggle
                  _buildToggle(),

                  // Content
                  Expanded(
                    child: _showServiceList
                        ? _buildServiceList(state)
                        : _buildTerminal(state),
                  ),

                  // Bottom action
                  if (isDone) _buildBottomAction(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(DeploymentState state, bool isDone) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDone
                          ? (state.overallStatus == DeploymentStatus.completed
                              ? AppTheme.successColor
                              : AppTheme.errorColor)
                          : AppTheme.seedColor,
                      boxShadow: isDone
                          ? null
                          : [
                              BoxShadow(
                                color: AppTheme.seedColor
                                    .withValues(alpha: 0.3 * _pulseController.value),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                    ),
                    child: Icon(
                      isDone
                          ? (state.overallStatus == DeploymentStatus.completed
                              ? Icons.check_rounded
                              : Icons.error_outline_rounded)
                          : Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone
                          ? (state.overallStatus == DeploymentStatus.completed
                              ? 'Deployment Complete'
                              : 'Deployment Failed')
                          : 'Deploying...',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.currentServiceName != null
                          ? 'Installing ${state.currentServiceName}'
                          : '${widget.profile.host} — ${state.completedCount}/${state.totalCount} services',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDone)
                IconButton(
                  onPressed: () => _showExitDialog(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(DeploymentState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.overallStatus == DeploymentStatus.connecting
                  ? null
                  : state.progress,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              color: AppTheme.seedColor,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF16162B),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showServiceList = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _showServiceList
                      ? AppTheme.seedColor.withValues(alpha: 0.2)
                      : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    'Services',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _showServiceList
                          ? AppTheme.seedColor
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showServiceList = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: !_showServiceList
                      ? AppTheme.seedColor.withValues(alpha: 0.2)
                      : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    'Terminal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: !_showServiceList
                          ? AppTheme.seedColor
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Copy logs button
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _copyLogs(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF16162B),
              ),
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyLogs() {
    final logs = _deploymentService.state.globalLog.join('\n');
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildServiceList(DeploymentState state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.services.length,
      itemBuilder: (context, index) {
        final svc = state.services[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1A1A2E),
            border: Border.all(
              color: svc.status == DeploymentStatus.deploying
                  ? AppTheme.seedColor.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      svc.serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (svc.duration != null)
                      Text(
                        '${svc.duration!.inSeconds}s',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
              ),
              StatusBadge(status: svc.status),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTerminal(DeploymentState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TerminalView(
        lines: state.globalLog,
        isActive: state.overallStatus == DeploymentStatus.deploying ||
            state.overallStatus == DeploymentStatus.connecting,
      ),
    );
  }

  Widget _buildBottomAction(DeploymentState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Go back to home
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('Home'),
              ),
            ),
            if (state.overallStatus == DeploymentStatus.completed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SSHTerminalScreen(profile: widget.profile),
                      ),
                    );
                  },
                  icon: const Icon(Icons.terminal_rounded, size: 18),
                  label: const Text('Terminal'),
                ),
              ),
            ],
            if (state.overallStatus == DeploymentStatus.failed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _deploymentService.reset();
                    _deploymentService.deploy(widget.profile);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    final state = _deploymentService.state;
    final isDone = state.overallStatus == DeploymentStatus.completed ||
        state.overallStatus == DeploymentStatus.failed ||
        state.overallStatus == DeploymentStatus.idle;

    if (isDone) {
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Deployment?'),
        content: const Text(
            'The deployment is still in progress. Already installed services will remain on the server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deploymentService.reset();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Cancel Deploy',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
  }
}
