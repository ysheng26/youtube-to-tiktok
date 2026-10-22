# Parts

A small native iOS app that turns a YouTube video into a swipeable series of one-minute parts. Built with SwiftUI and YouTube’s embedded player. No API key, backend, account, or third-party packages.

## Run

1. Open `Parts.xcodeproj` in Xcode.
2. Select the **Parts** scheme and an iPhone simulator, then Run (⌘R).
3. For a physical iPhone, choose the same development team for **Parts** and **PartsShare** under **Signing & Capabilities**, enable the shared App Group as described below, and select your device. The app supports iOS 17 and later.
4. Paste a YouTube link and tap **Watch in parts**, or try the sample video.

Tap Play below the YouTube player to begin if playback does not start automatically. Swipe in the area below the player to move between parts, use the navigation buttons, or choose **All parts**. Each part automatically loops back to its own start until you navigate away. The play/pause button and seek bar below the video control only the current part. The last part may be shorter than a minute. Progress and the video library are saved locally; long-press a library entry to remove it.

## Share from YouTube or Safari

1. In Xcode, select both **Parts** and **PartsShare** targets and enable **App Groups** under **Signing & Capabilities**. Use the same development team and select `group.com.shengy.parts` for both targets. Both entitlements files already declare this group; your Apple developer team must register/provision it. If this group is unavailable to your team, choose a unique group and update both entitlements files and `ShareInbox.appGroup` in `Parts/Core/ShareInbox.swift` to match.
2. Build and reinstall **Parts** so iOS registers its embedded extension.
3. In YouTube or Safari, tap **Share**, choose **Save to Parts** (look under **More** if needed), then tap **Save video** and **Done**.
4. Open or return to Parts. The video is saved in your library; tap it whenever you want to watch.

The extension saves a link; it does not launch the main app automatically. Links wait in an App Group inbox while Parts is closed and import when it launches or becomes active. Sharing an existing video preserves its playback progress. Non-YouTube links show an explanation instead of being added. If signing reports an App Group error, check the group registration, both targets’ team and bundle IDs, and their provisioning profiles. Copy/paste remains available without the extension.

Device smoke test: share a video while Parts is closed, reopen it, verify it appears in the library without forcing playback, watch part of it, then share it again and confirm the saved progress remains. Also try sharing from Safari, unsupported text, and several videos before reopening Parts.

## Watch immediately from the Share Sheet

Create the separate **Watch in Parts** shortcut using the [setup instructions](Shortcuts/README.md). It opens the app with a `parts://watch?url=…` link, saves the video, and goes straight to the player. It works without an App Group; the **Save to Parts** extension still uses its shared inbox. The shortcut requires one-time setup in Shortcuts and is not installed automatically with the app.

The app validates incoming YouTube links, handles launches while closed or already running, and waits for the player to appear before acknowledging the request. A new request dismisses an existing player before opening the requested video, preserving the previous video’s progress.

## Scope

This version segments playback of the original video. It does not download, render, or export clips. The portrait watch screen uses Fit: the full video stays centered without cropping, against a clean black background. Swiping vertically moves the video with your finger and slides to the selected part; short or boundary swipes spring back. Reduce Motion uses a fade instead. The title and compact playback controls sit near the bottom. YouTube’s controls are hidden using supported player parameters; native controls sit below the video. Parts use fixed 60-second boundaries rather than detecting sentences or scenes. Link input supports watch, short, embed, live-recording, and youtu.be URLs. Live streams and videos whose creators disable embedding cannot be played as parts. Internet access is required. A Share Extension imports YouTube links from the iOS Share Sheet. In-app YouTube search is not included yet.

YouTube owns the embedded player's overlays. `rel=0` restricts related videos to the same channel; it does not remove suggestions. `iv_load_policy=3` suppresses annotations where supported, but does not remove all end cards, branding, ads, or pause overlays. The player loops each part and restores the selected video if a suggestion changes playback. A guarantee of video-only presentation requires a video source the app can play natively, rather than a YouTube embed.

## Checks

```sh
swift test
node --test Tests/PlayerTests/player.test.cjs
xcodebuild -project Parts.xcodeproj -scheme Parts -sdk iphonesimulator \
  -configuration Debug -derivedDataPath /tmp/parts-build CODE_SIGNING_ALLOWED=NO build
```

Swift tests cover link validation, shared-text extraction, the shared inbox, part boundaries, and persisted progress. Node tests execute the actual bundled player script with a simulated YouTube API to check looping boundaries, navigation, final parts, pause, seeking, and resume.

The app and Share Extension Swift sources pass compiler checks. Earlier simulator builds passed; with the new app icon, full asset compilation is blocked here by unavailable CoreSimulator runtimes. All eight Swift tests pass, including the shared inbox tests. The environment blocks CoreSimulator service access, so Share Sheet behavior and real YouTube playback still need a simulator or device smoke test. Physical-device builds also require provisioning the App Group for both targets.

## Implementation

- `Parts/Core/Video.swift`: link parsing, part calculations, saved-video model.
- `Parts/Core/ShareInbox.swift`: shared-text parsing and the file-based App Group inbox.
- `PartsShare/`: Share Sheet extension, activation rules, and entitlements.
- `Parts/App/`: SwiftUI screens, local library, WKWebView bridge.
- `Parts/Resources/player.html`: YouTube IFrame API player and segment playback.

The WebView supplies the app’s bundle identifier as its HTTPS base URL and player origin, following [YouTube’s embedded player identification guidance](https://developers.google.com/youtube/terms/required-minimum-functionality#api-client-identity-and-credentials). Playback uses the [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference).
# youtube-to-tiktok
# youtube-to-tiktok
# youtube-to-tiktok
# youtube-to-tiktok
