import 'package:flutter/material.dart';

enum ServiceCategory {
  containerization,
  versionControl,
  languages,
  editors,
  shell,
  networking,
  databases,
  devtools,
}

String serviceCategoryLabel(ServiceCategory cat) {
  switch (cat) {
    case ServiceCategory.containerization:
      return 'Containers';
    case ServiceCategory.versionControl:
      return 'Version Control';
    case ServiceCategory.languages:
      return 'Languages & Runtimes';
    case ServiceCategory.editors:
      return 'Editors';
    case ServiceCategory.shell:
      return 'Shell & Terminal';
    case ServiceCategory.networking:
      return 'Networking';
    case ServiceCategory.databases:
      return 'Databases';
    case ServiceCategory.devtools:
      return 'Dev Tools';
  }
}

IconData serviceCategoryIcon(ServiceCategory cat) {
  switch (cat) {
    case ServiceCategory.containerization:
      return Icons.inventory_2_rounded;
    case ServiceCategory.versionControl:
      return Icons.account_tree_rounded;
    case ServiceCategory.languages:
      return Icons.code_rounded;
    case ServiceCategory.editors:
      return Icons.edit_rounded;
    case ServiceCategory.shell:
      return Icons.terminal_rounded;
    case ServiceCategory.networking:
      return Icons.lan_rounded;
    case ServiceCategory.databases:
      return Icons.storage_rounded;
    case ServiceCategory.devtools:
      return Icons.build_rounded;
  }
}

class CredentialField {
  final String key;
  final String label;
  final String hint;
  final bool isSecret;

  const CredentialField({
    required this.key,
    required this.label,
    required this.hint,
    this.isSecret = true,
  });
}

class ServiceDefinition {
  final String id;
  final String name;
  final String description;
  final String iconChar;
  final ServiceCategory category;
  final List<String> dependencies;
  final List<CredentialField> credentialFields;
  final String Function(Map<String, String> creds) installScript;
  final Color accentColor;

  const ServiceDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.iconChar,
    required this.category,
    this.dependencies = const [],
    this.credentialFields = const [],
    required this.installScript,
    this.accentColor = const Color(0xFF6C5CE7),
  });
}
