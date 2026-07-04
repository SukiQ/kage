/// 渲染含 `{{name}}` 占位符的 Prompt 模板。
String renderTemplate(String body, Map<String, String> params) {
  var out = body;
  params.forEach((key, value) {
    out = out.replaceAll('{{$key}}', value);
  });
  return out;
}
