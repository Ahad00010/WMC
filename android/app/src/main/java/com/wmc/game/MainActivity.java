package com.wmc.game;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import org.json.JSONObject;
import java.util.Locale;

public class MainActivity extends Activity {
    private WebView webView;
    private Uri pendingCallback;
    private boolean pageReady;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        webView = new WebView(this);
        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);
        webView.addJavascriptInterface(new AuthBridge(), "WMCAndroid");
        webView.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (isGamePage(uri)) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); }
                catch (ActivityNotFoundException ignored) { }
                return true;
            }
            @Override public void onPageStarted(WebView view, String url, android.graphics.Bitmap icon) { pageReady = false; }
            @Override public void onPageFinished(WebView view, String url) {
                pageReady = isGamePage(Uri.parse(url));
                deliverCallback();
            }
        });
        setContentView(webView);
        receiveCallback(getIntent());
        if (state == null || webView.restoreState(state) == null) webView.loadUrl("https://ahad00010.github.io/WMC/");
    }
    private boolean isGamePage(Uri uri) {
        String path = uri.getPath();
        return "https".equalsIgnoreCase(uri.getScheme()) && "ahad00010.github.io".equalsIgnoreCase(uri.getHost()) && path != null && (path.equals("/WMC/") || path.equals("/WMC/index.html"));
    }
    private class AuthBridge {
        @JavascriptInterface public void openAuth(String url) {
            Uri uri = Uri.parse(url);
            String host = uri.getHost();
            if (!"https".equalsIgnoreCase(uri.getScheme()) || host == null || !host.toLowerCase(Locale.ROOT).endsWith(".supabase.co") || !"/auth/v1/authorize".equals(uri.getPath())) return;
            runOnUiThread(() -> {
                try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); }
                catch (ActivityNotFoundException ignored) { }
            });
        }
    }
    private void receiveCallback(Intent intent) {
        Uri uri = intent == null ? null : intent.getData();
        if (uri != null && "wmc".equals(uri.getScheme()) && "auth-callback".equals(uri.getHost())) {
            pendingCallback = uri;
            deliverCallback();
        }
    }
    private void deliverCallback() {
        if (!pageReady || pendingCallback == null) return;
        String code = pendingCallback.getQueryParameter("code");
        String error = pendingCallback.getQueryParameter("error");
        pendingCallback = null;
        webView.evaluateJavascript("window.wmcAuthCallback && window.wmcAuthCallback(" + JSONObject.quote(code == null ? "" : code) + "," + JSONObject.quote(error == null ? "" : error) + ")", null);
    }
    @Override protected void onNewIntent(Intent intent) { super.onNewIntent(intent); setIntent(intent); receiveCallback(intent); }
    @Override protected void onSaveInstanceState(Bundle state) { webView.saveState(state); super.onSaveInstanceState(state); }
    @Override protected void onDestroy() { webView.destroy(); super.onDestroy(); }
}
