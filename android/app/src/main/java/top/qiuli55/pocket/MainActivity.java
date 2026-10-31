package top.qiuli55.pocket;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

/**
 * 小荷包 WebView 外壳：加载线上站点，保留登录态与离线兜底。
 * 页面本身仍是 index.html，所以功能更新无需重新发版。
 */
public class MainActivity extends Activity {

    private static final String HOME = "https://qiuli55.github.io/Money-love-me-ok/";
    private static final String ALLOWED_HOST_1 = "qiuli55.github.io";
    private static final String ALLOWED_HOST_2 = "demo.qiuli55.top";

    private WebView web;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        web = new WebView(this);
        web.setBackgroundColor(Color.parseColor("#FAF9F6"));
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);

        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(web, true);

        web.addJavascriptInterface(new Bridge(), "PocketApp");

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return openExternallyIfNeeded(request.getUrl());
            }

            @SuppressWarnings("deprecation")
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                return openExternallyIfNeeded(Uri.parse(url));
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) {
                    showOffline();
                }
            }
        });

        if (savedInstanceState == null) {
            web.loadUrl(HOME);
        } else {
            web.restoreState(savedInstanceState);
        }

        // 首次启动时把系统栏图标调整为深色，避免奶油底色上看不清
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        }
    }

    /** 站点内链接留在应用内，其余（如 GitHub、电话）交给系统处理 */
    private boolean openExternallyIfNeeded(Uri uri) {
        String scheme = uri.getScheme();
        String host = uri.getHost();
        if (host != null && (ALLOWED_HOST_1.equals(host) || ALLOWED_HOST_2.equals(host))) {
            return false;
        }
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            if (!"http".equals(scheme) && !"https".equals(scheme)) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            }
            startActivity(intent);
        } catch (Exception ignored) {
        }
        return true;
    }

    private void showOffline() {
        String html = "<!doctype html><html><head><meta charset='utf-8'>"
                + "<meta name='viewport' content='width=device-width,initial-scale=1'>"
                + "<style>body{margin:0;height:100vh;display:flex;flex-direction:column;"
                + "align-items:center;justify-content:center;background:#FAF9F6;color:#1A1A1A;"
                + "font-family:-apple-system,'PingFang SC',sans-serif}"
                + "h2{font-size:18px;font-weight:600;margin:0 0 8px}p{font-size:14px;color:#666;margin:0 0 24px}"
                + "button{border:0;border-radius:999px;padding:12px 28px;font-size:15px;"
                + "background:#D8F828;color:#1A1A1A;font-weight:600}</style></head><body>"
                + "<h2>网络好像断了</h2><p>连上网络后再试一次</p>"
                + "<button onclick='PocketApp.retry()'>重新加载</button></body></html>";
        web.loadDataWithBaseURL("about:blank", html, "text/html", "utf-8", null);
    }

    private class Bridge {
        @JavascriptInterface
        public void retry() {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    web.loadUrl(HOME);
                }
            });
        }
    }

    @Override
    public void onBackPressed() {
        if (web != null && web.canGoBack()) {
            web.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }
}
