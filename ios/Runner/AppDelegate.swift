import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let center = UNUserNotificationCenter.current()
    center.delegate = self

    let runCategory = UNNotificationCategory(
      identifier: "RUN_SESSION",
      actions: [],
      intentIdentifiers: [],
      options: []
    )
    center.setNotificationCategories([runCategory])

    center.requestAuthorization(options: [.alert, .badge]) { _, _ in }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
