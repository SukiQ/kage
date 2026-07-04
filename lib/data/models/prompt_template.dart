class TemplateParameter {
  const TemplateParameter({
    required this.name,
    required this.label,
    this.hint = '',
    this.defaultValue = '',
    this.required = true,
    this.multiline = false,
  });

  final String name;
  final String label;
  final String hint;
  final String defaultValue;
  final bool required;
  final bool multiline;

  factory TemplateParameter.fromJson(Map<String, dynamic> json) =>
      TemplateParameter(
        name: json['name'] as String,
        label: json['label'] as String? ?? json['name'] as String,
        hint: json['hint'] as String? ?? '',
        defaultValue: json['defaultValue'] as String? ?? '',
        required: json['required'] as bool? ?? true,
        multiline: json['multiline'] as bool? ?? false,
      );
}

class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.body,
    this.category = '通用',
    this.parameters = const [],
    this.skillId,
  });

  final String id;
  final String name;
  final String description;
  final String body;
  final String category;
  final List<TemplateParameter> parameters;
  final String? skillId;

  factory PromptTemplate.fromJson(Map<String, dynamic> json) => PromptTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    body: json['body'] as String,
    category: json['category'] as String? ?? '通用',
    skillId: json['skillId'] as String?,
    parameters:
        (json['parameters'] as List?)
            ?.map((e) => TemplateParameter.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
