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

    hideTrafficLights()
  }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    super.makeKeyAndOrderFront(sender)
    hideTrafficLights()
  }

  override func becomeKey() {
    super.becomeKey()
    hideTrafficLights()
  }

  /// 隐藏 macOS 原生交通灯按钮（关闭/最小化/最大化），改用应用内自绘控件。
  /// 在多个窗口生命周期回调中同步调用，确保按钮视图已创建（release 线程模型下加载时序与 debug 不同）。
  private func hideTrafficLights() {
    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true
  }
}
