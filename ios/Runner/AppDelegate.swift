import Flutter
import UIKit

/// Bridges [GeneratedPluginRegistrant] into Flutter's UIScene launch path.
/// Required on iOS 27+ when using FlutterSceneDelegate (plugins must not be
/// registered only in didFinishLaunching — the engine may not exist yet).
final class AwdaPluginRegistrant: NSObject, FlutterPluginRegistrant {
  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let awdaPluginRegistrant = AwdaPluginRegistrant()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Used by FlutterViewController / FlutterSceneDelegate when the engine
    // is created from the Main storyboard under UIScene.
    pluginRegistrant = awdaPluginRegistrant
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
