import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 项目图标集中入口：统一使用 Lucide（lucide_icons_flutter，字体由包自带）。
/// 调用处 `Icon(KageIcons.send)`。
abstract final class KageIcons {
  // 通用操作
  static const settings = LucideIcons.settings;
  static const send = LucideIcons.send;
  static const stop = LucideIcons.circleStop;
  static const add = LucideIcons.plus;
  static const delete = LucideIcons.trash2;
  static const history = LucideIcons.history;
  static const back = LucideIcons.arrowLeft;
  static const dropdown = LucideIcons.chevronDown;
  static const chevronRight = LucideIcons.chevronRight;
  static const sidebarOpen = LucideIcons.panelLeftOpen;
  static const sidebarClose = LucideIcons.panelLeftClose;
  static const play = LucideIcons.play;
  static const check = LucideIcons.circleCheck;
  static const alert = LucideIcons.triangleAlert;
  static const tool = LucideIcons.terminal;
  static const restart = LucideIcons.rotateCcw;
  static const contrast = LucideIcons.contrast;

  // 文件夹
  static const folder = LucideIcons.folder;
  static const folderOff = LucideIcons.folderX;
  static const folderOpen = LucideIcons.folderOpen;

  // 功能
  static const skills = LucideIcons.sparkles;

  // 窗口控制
  static const winMinimize = LucideIcons.minus;
  static const winMaximize = LucideIcons.square;
  static const winClose = LucideIcons.x;

  // 侧栏菜单
  static const newSession = LucideIcons.messageSquarePlus;
  static const chat = LucideIcons.messageSquare;
  static const codeBuild = LucideIcons.hammer;
  static const codeReview = LucideIcons.shieldCheck;
  static const exportApi = LucideIcons.share;

  // 对话框
  static const paperclip = LucideIcons.paperclip;

  // 模式徽标
  static const modeDefault = LucideIcons.bot;
  static const modePlan = LucideIcons.clipboardList;
  static const modeAccept = LucideIcons.filePenLine;
  static const modeBypass = LucideIcons.shieldOff;

  // 模型徽标
  static const model = LucideIcons.layers;
}
