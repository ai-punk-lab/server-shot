import 'package:flutter/material.dart';
import '../services/deployment_service.dart';

class StatusBadge extends StatelessWidget {
  final DeploymentStatus status;
  final double size;

  const StatusBadge({
    super.key,
    required this.status,
    this.size = 8,
  });

  Color get color {
    switch (status) {
      case DeploymentStatus.idle:
        return Colors.white.withValues(alpha: 0.3);
      case DeploymentStatus.connecting:
        return const Color(0xFFFDAA5E);
      case DeploymentStatus.deploying:
        return const Color(0xFF6C5CE7);
      case DeploymentStatus.completed:
        return const Color(0xFF00B894);
      case DeploymentStatus.failed:
        return const Color(0xFFFF6B6B);
    }
  }

  String get label {
    switch (status) {
      case DeploymentStatus.idle:
        return 'Pending';
      case DeploymentStatus.connecting:
        return 'Connecting';
      case DeploymentStatus.deploying:
        return 'Installing';
      case DeploymentStatus.completed:
        return 'Done';
      case DeploymentStatus.failed:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == DeploymentStatus.deploying)
          SizedBox(
            width: size + 4,
            height: size + 4,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: color,
            ),
          )
        else
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                if (status == DeploymentStatus.completed ||
                    status == DeploymentStatus.failed)
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
              ],
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
