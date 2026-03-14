import 'dart:convert';

class ServerProfile {
  final String id;
  String name;
  String host;
  int port;
  String username;
  String password;
  String? privateKey;
  List<String> selectedServices;
  Map<String, Map<String, String>> credentials;
  // Deploy user settings
  bool createUser;
  String? deployUsername;
  String? deployPassword;
  bool deploySudo;
  bool deploySudoNoPassword;
  // Custom SSH users
  List<Map<String, String>> sshUsers;
  DateTime createdAt;
  DateTime updatedAt;

  ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password = '',
    this.privateKey,
    this.selectedServices = const [],
    this.credentials = const {},
    this.createUser = false,
    this.deployUsername,
    this.deployPassword,
    this.deploySudo = true,
    this.deploySudoNoPassword = true,
    this.sshUsers = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// The username under which services will be installed
  String get effectiveDeployUser =>
      createUser && deployUsername != null && deployUsername!.isNotEmpty
          ? deployUsername!
          : username;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'privateKey': privateKey,
        'selectedServices': selectedServices,
        'credentials': credentials.map(
          (k, v) => MapEntry(k, v),
        ),
        'createUser': createUser,
        'deployUsername': deployUsername,
        'deployPassword': deployPassword,
        'deploySudo': deploySudo,
        'deploySudoNoPassword': deploySudoNoPassword,
        'sshUsers': sshUsers,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      password: json['password'] as String? ?? '',
      privateKey: json['privateKey'] as String?,
      selectedServices: List<String>.from(json['selectedServices'] ?? []),
      credentials: (json['credentials'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
          ) ??
          {},
      createUser: json['createUser'] as bool? ?? false,
      deployUsername: json['deployUsername'] as String?,
      deployPassword: json['deployPassword'] as String?,
      deploySudo: json['deploySudo'] as bool? ?? true,
      deploySudoNoPassword: json['deploySudoNoPassword'] as bool? ?? true,
      sshUsers: (json['sshUsers'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory ServerProfile.deserialize(String data) =>
      ServerProfile.fromJson(jsonDecode(data) as Map<String, dynamic>);

  ServerProfile copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    List<String>? selectedServices,
    Map<String, Map<String, String>>? credentials,
    bool? createUser,
    String? deployUsername,
    String? deployPassword,
    bool? deploySudo,
    bool? deploySudoNoPassword,
    List<Map<String, String>>? sshUsers,
  }) {
    return ServerProfile(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      selectedServices: selectedServices ?? this.selectedServices,
      credentials: credentials ?? this.credentials,
      createUser: createUser ?? this.createUser,
      deployUsername: deployUsername ?? this.deployUsername,
      deployPassword: deployPassword ?? this.deployPassword,
      deploySudo: deploySudo ?? this.deploySudo,
      deploySudoNoPassword: deploySudoNoPassword ?? this.deploySudoNoPassword,
      sshUsers: sshUsers ?? this.sshUsers,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
