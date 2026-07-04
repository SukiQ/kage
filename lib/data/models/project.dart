class KageProject {
  KageProject({
    required this.id,
    required this.name,
    required this.path,
    this.permissionMode = 'default',
    this.sonarProjectKey,
  });

  final String id;
  final String name;
  final String path;
  final String permissionMode;

  /// SonarQube 项目 key（用于拉取扫描报告），未配置则为 null。
  final String? sonarProjectKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'permissionMode': permissionMode,
    if (sonarProjectKey != null) 'sonarProjectKey': sonarProjectKey,
  };

  factory KageProject.fromJson(Map<String, dynamic> json) => KageProject(
    id: json['id'] as String,
    name: json['name'] as String,
    path: json['path'] as String,
    permissionMode: json['permissionMode'] as String? ?? 'default',
    sonarProjectKey: json['sonarProjectKey'] as String?,
  );

  KageProject copyWith({
    String? id,
    String? name,
    String? path,
    String? permissionMode,
    String? sonarProjectKey,
  }) => KageProject(
    id: id ?? this.id,
    name: name ?? this.name,
    path: path ?? this.path,
    permissionMode: permissionMode ?? this.permissionMode,
    sonarProjectKey: sonarProjectKey ?? this.sonarProjectKey,
  );
}
