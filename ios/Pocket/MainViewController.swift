import UIKit
import WebKit

// 口袋荷包 iOS 外壳：WKWebView 承载线上页面，
// 只放行自家域名；外链、电话、短信一律交给系统打开。
final class MainViewController: UIViewController {

    private let homeURL = URL(string: "https://qiuli55.github.io/Money-love-me-ok/")!
    private let allowedHosts: Set<String> = ["qiuli55.github.io", "demo.qiuli55.top"]
    private let cream = UIColor(named: "Cream") ?? UIColor(red: 0.980, green: 0.976, blue: 0.965, alpha: 1)
    private let lime = UIColor(red: 0.847, green: 0.973, blue: 0.157, alpha: 1)
    private let ink = UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1)

    private var webView: WKWebView!
    private var offlineView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = cream
        setupWebView()
        loadHome()
    }

    // MARK: - WebView

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // 登录态放进默认数据仓库，保证本地存储与 Cookie 长期保留
        config.websiteDataStore = .default()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        // 侧滑返回（与原生 App 手势一致），页面本身无需额外返回按钮
        web.allowsBackForwardNavigationGestures = true
        // 铺满全屏，安全区交给页面里的 env(safe-area-inset-*) 处理，避免二次留白
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.contentInset = .zero
        web.alpha = 0
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            web.topAnchor.constraint(equalTo: view.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        webView = web
    }

    private func loadHome() {
        webView.load(URLRequest(url: homeURL))
    }

    // MARK: - 断网兜底页

    private func showOffline() {
        guard offlineView == nil else { return }

        let container = UIView()
        container.backgroundColor = cream
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let logo = UIImageView(image: UIImage(named: "LaunchLogo"))
        logo.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "连不上网络"
        title.font = .systemFont(ofSize: 17, weight: .bold)
        title.textColor = ink
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "检查一下网络，再试一次"
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = UIColor(white: 0.55, alpha: 1)
        subtitle.textAlignment = .center

        let button = UIButton(type: .system)
        button.setTitle("重新加载", for: .normal)
        button.setTitleColor(ink, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        button.backgroundColor = lime
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(retry), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 132).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let stack = UIStackView(arrangedSubviews: [logo, title, subtitle, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(22, after: subtitle)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            logo.widthAnchor.constraint(equalToConstant: 96),
            logo.heightAnchor.constraint(equalToConstant: 96),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -20)
        ])
        offlineView = container
    }

    private func hideOffline() {
        offlineView?.removeFromSuperview()
        offlineView = nil
    }

    @objc private func retry() {
        hideOffline()
        loadHome()
    }
}

// MARK: - 导航策略

extension MainViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "http" || scheme == "https" {
            if let host = url.host, allowedHosts.contains(host) {
                decisionHandler(.allow)
            } else {
                // 外链交系统浏览器，避免把用户困在外壳里
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
            return
        }
        // tel: / sms: / mailto: / 其他 scheme
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideOffline()
        UIView.animate(withDuration: 0.2) { webView.alpha = 1 }
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        // 主动取消（比如跳外链）不算失败
        if (error as NSError).code == NSURLErrorCancelled { return }
        showOffline()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        showOffline()
    }

    // 系统回收网页进程时自动恢复，避免白屏
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - target="_blank" 处理

extension MainViewController: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if let host = url.host, allowedHosts.contains(host) {
                webView.load(navigationAction.request)
            } else {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }
}
