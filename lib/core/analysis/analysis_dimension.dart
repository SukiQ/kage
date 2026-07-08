/// 代码质量治理的五大分析维度
enum AnalysisDimension {
  codeQuality,
  securityReview,
  archAnalysis,
  perfAnalysis,
  qualityTest,
}

extension AnalysisDimensionX on AnalysisDimension {
  String get label => switch (this) {
        AnalysisDimension.codeQuality => '代码质量',
        AnalysisDimension.securityReview => '安全审查',
        AnalysisDimension.archAnalysis => '架构分析',
        AnalysisDimension.perfAnalysis => '性能分析',
        AnalysisDimension.qualityTest => '质量测试',
      };

  String get icon => switch (this) {
        AnalysisDimension.codeQuality => 'code',
        AnalysisDimension.securityReview => 'shield',
        AnalysisDimension.archAnalysis => 'layers',
        AnalysisDimension.perfAnalysis => 'gauge',
        AnalysisDimension.qualityTest => 'flask',
      };

  String get description => switch (this) {
        AnalysisDimension.codeQuality => 'Bug、代码异味、重复代码、技术债',
        AnalysisDimension.securityReview => '漏洞、安全热点、OWASP 风险',
        AnalysisDimension.archAnalysis => '模块耦合、依赖分析、设计模式',
        AnalysisDimension.perfAnalysis => '性能热点、算法复杂度、资源使用',
        AnalysisDimension.qualityTest => '测试覆盖率、测试质量、缺失用例',
      };

  /// 路由路径
  String get route => switch (this) {
        AnalysisDimension.codeQuality => '/code-quality',
        AnalysisDimension.securityReview => '/security',
        AnalysisDimension.archAnalysis => '/architecture',
        AnalysisDimension.perfAnalysis => '/performance',
        AnalysisDimension.qualityTest => '/testing',
      };
}
