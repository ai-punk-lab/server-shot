import 'dart:convert';

class CredentialPreset {
  final String id;
  String name;
  Map<String, Map<String, String>> credentials;
  DateTime createdAt;

  CredentialPreset({
    required this.id,
    required this.name,
    this.credentials = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'credentials': credentials.map((k, v) => MapEntry(k, v)),
        'createdAt': createdAt.toIso8601String(),
      };

  factory CredentialPreset.fromJson(Map<String, dynamic> json) {
    return CredentialPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      credentials: (json['credentials'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
          ) ??
          {},
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory CredentialPreset.deserialize(String data) =>
      CredentialPreset.fromJson(jsonDecode(data) as Map<String, dynamic>);
}
