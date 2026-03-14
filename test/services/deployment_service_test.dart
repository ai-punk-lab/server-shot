import 'package:flutter_test/flutter_test.dart';
import 'package:servershot/services/deployment_service.dart';

void main() {
  group('DeploymentService', () {
    test('initial state is idle', () {
      final service = DeploymentService();
      expect(service.state.overallStatus, DeploymentStatus.idle);
      expect(service.state.completedCount, 0);
      expect(service.state.totalCount, 0);
      expect(service.state.progress, 0.0);
      expect(service.state.globalLog, isEmpty);
      service.dispose();
    });

    test('reset clears state', () async {
      final service = DeploymentService();
      await service.reset();
      expect(service.state.overallStatus, DeploymentStatus.idle);
      expect(service.state.services, isEmpty);
      service.dispose();
    });
  });

  group('DeploymentState', () {
    test('progress calculation', () {
      final state = DeploymentState(completedCount: 3, totalCount: 10);
      expect(state.progress, 0.3);
    });

    test('progress is 0 when no services', () {
      final state = DeploymentState(completedCount: 0, totalCount: 0);
      expect(state.progress, 0.0);
    });

    test('currentServiceName returns name when set', () {
      final state = DeploymentState(
        currentServiceId: 'docker',
        services: [
          ServiceDeploymentState(serviceId: 'docker', serviceName: 'Docker'),
        ],
      );
      expect(state.currentServiceName, 'Docker');
    });

    test('currentServiceName returns null when not set', () {
      final state = DeploymentState();
      expect(state.currentServiceName, isNull);
    });
  });

  group('ServiceDeploymentState', () {
    test('duration is null before start', () {
      final state = ServiceDeploymentState(
        serviceId: 'test',
        serviceName: 'Test',
      );
      expect(state.duration, isNull);
    });

    test('duration calculates correctly', () {
      final now = DateTime.now();
      final state = ServiceDeploymentState(
        serviceId: 'test',
        serviceName: 'Test',
        startedAt: now.subtract(const Duration(seconds: 5)),
        completedAt: now,
      );
      expect(state.duration!.inSeconds, 5);
    });
  });
}
