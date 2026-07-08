class KageProject {
  KageProject({
    required this.id,
    required this.name,
    required this.path,
    this.permissionMode = 'default',
  });

  final String id;

  /// 项目名称，同时作为 SonarQube project key。
  final String name;
  final String path;
  final String permissionMode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'permissionMode': permissionMode,
  };

  factory KageProject.fromJson(Map<String, dynamic> json) => KageProject(
    id: json['id'] as String,
    name: json['name'] as String,
    path: json['path'] as String,
    permissionMode: json['permissionMode'] as String? ?? 'default',
  );

  KageProject copyWith({
    String? id,
    String? name,
    String? path,
    String? permissionMode,
  }) => KageProject(
    id: id ?? this.id,
    name: name ?? this.name,
    path: path ?? this.path,
    permissionMode: permissionMode ?? this.permissionMode,
  );
}
