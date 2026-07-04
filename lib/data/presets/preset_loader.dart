import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/prompt_template.dart';

/// 内置预设加载器：从 assets/presets/templates/ 读取全部内置模板（不再区分角色）。
class PresetLoader {
  static Future<List<PromptTemplate>> loadTemplates() async {
    final ids = ['backend', 'frontend', 'product', 'qa'];
    final all = <PromptTemplate>[];
    for (final id in ids) {
      final raw = await rootBundle.loadString(
        'assets/presets/templates/$id.json',
      );
      final list = (jsonDecode(raw) as List)
          .map((e) => PromptTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      all.addAll(list);
    }
    return all;
  }
}
