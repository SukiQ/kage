class KageSkill {
  const KageSkill({
    required this.name,
    required this.description,
    this.source = SkillSource.user,
  });

  final String name;
  final String description;
  final SkillSource source;

  factory KageSkill.fromFrontmatter(
    String name,
    String description, {
    SkillSource source = SkillSource.user,
  }) => KageSkill(name: name, description: description, source: source);
}

enum SkillSource { builtin, user }
