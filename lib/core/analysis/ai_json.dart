import 'dart:convert';

/// 从 AI 文本中提取并容错解析 JSON。
///
/// AI 经常输出"几乎合法"的 JSON，最典型的破坏是**字符串值内部的裸双引号未转义**
///（如 `"硬编码为"0/10 * * * * ?"导致..."`）。这里在标准 `jsonDecode` 失败后，
/// 用启发式修复字符串内部的裸双引号再重试。
class AiJson {
  const AiJson._();

  /// 提取 JSON 文本：优先 ```json``` 代码块，否则取首个 { 到末个 }。
  static String? extract(String text) {
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    final candidate = fenced?.group(1)?.trim() ?? text.trim();
    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start < 0 || end < 0 || end <= start) return null;
    return candidate.substring(start, end + 1);
  }

  /// 修复 AI 输出常见的 JSON 破坏：把字符串内部未转义的双引号转义为 `\"`。
  ///
  /// 启发式：字符串内遇到 `"` 时，向后跳过空白看下一个结构字符，
  /// 若为 `, } ] :` 之一则视为字符串结束，否则视为内部引号予以转义。
  static String repair(String json) {
    final buf = StringBuffer();
    var inStr = false;
    var escaped = false;
    for (var i = 0; i < json.length; i++) {
      final ch = json[i];
      if (escaped) {
        buf.write(ch);
        escaped = false;
        continue;
      }
      if (ch == r'\') {
        buf.write(ch);
        escaped = true;
        continue;
      }
      if (ch == '"') {
        if (!inStr) {
          inStr = true;
          buf.write(ch);
        } else {
          final next = _nextNonSpace(json, i + 1);
          if (next == null || const [',', '}', ']', ':'].contains(next)) {
            inStr = false;
            buf.write(ch);
          } else {
            buf.write(r'\"');
          }
        }
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static String? _nextNonSpace(String s, int i) {
    for (; i < s.length; i++) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;
      return c;
    }
    return null;
  }

  /// 提取 + 解析。先标准解析，失败则修复后重试。成功返回 Map，否则 null。
  static Map<String, dynamic>? decodeLoose(String text) {
    final raw = extract(text);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      try {
        return jsonDecode(repair(raw)) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }
}
