# WMC Android wrapper

This Android app loads the live GitHub Pages game in a landscape WebView. It needs internet, and website updates do not require a new APK. The APK itself only needs rebuilding for changes to the wrapper. External links open in the device's browser. The game and its third-party scripts are fetched over HTTPS.

## Download an APK

On GitHub, open Actions → Build Android APK → a successful run → Artifacts → WMC-debug-APK. Extract the ZIP and install `app-debug.apk` on Android. GitHub may require sign-in to download artifacts. This is a debug-signed build for testing, not a Play Store release. Allow installation from the source you used to open the APK if Android asks. Debug artifacts expire according to the repository's Actions retention settings.

## Build locally

Open the `android` folder in Android Studio, install the Android SDK 35 and use JDK 17, then use Build → Build APK(s). Alternatively, with Gradle 8.9 installed, run `gradle assembleDebug` inside `android`. The APK is at `app/build/outputs/apk/debug/app-debug.apk`.

Updates to the page's HTML, CSS, or inline JavaScript are detected automatically by the game. Updates only to external files (such as `bike-model.txt`) require a corresponding change to `index.html` to notify existing sessions. A refresh resets an active game session. It can take time for GitHub Pages and caches to propagate a deployment.
