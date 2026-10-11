import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MsSecureScreen") {
      SecureScreen.register(messenger: registrar.messenger())
    }
  }
}

/// «Личный сейф» (lib/core/security/secure_screen.dart): while it is open,
/// the app-switcher snapshot is covered with a blur. iOS has no FLAG_SECURE
/// and screenshots can't be blocked; the snapshot is what would leak.
final class SecureScreen {
  static var on = false
  private static var cover: UIView?

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ms/secure_screen", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "set" {
        SecureScreen.on = (call.arguments as? Bool) ?? false
        if !SecureScreen.on { SecureScreen.uncover() }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    let center = NotificationCenter.default
    center.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { _ in
      SecureScreen.coverIfOn()
    }
    center.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in
      SecureScreen.uncover()
    }
  }

  private static func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  private static func coverIfOn() {
    guard on, cover == nil, let window = keyWindow() else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    cover = blur
  }

  private static func uncover() {
    cover?.removeFromSuperview()
    cover = nil
  }
}
