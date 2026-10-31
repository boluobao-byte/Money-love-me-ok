import UIKit

// 极简 App 生命周期：不使用 Scene，直接由 AppDelegate 持有窗口，
// 这样在任何 iOS 13+ 系统上行为一致，也和安卓外壳保持同构。
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MainViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
