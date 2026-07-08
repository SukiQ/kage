import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // 隐藏 macOS 原生交通灯按钮（关闭/最小化/最大化），改用应用内自绘控件
    // 延迟到下一个 runloop，确保按钮视图已创建
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.standardWindowButton(.closeButton)?.isHidden = true
      self.standardWindowButton(.miniaturizeButton)?.isHidden = true
      self.standardWindowButton(.zoomButton)?.isHidden = true
    }
  }
}
