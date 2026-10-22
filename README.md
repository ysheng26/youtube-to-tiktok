# Parts

A small native iOS app that turns a YouTube video into a swipeable series of one-minute parts. Built with SwiftUI and YouTube’s embedded player. No API key, backend, account, or third-party packages.

## Run

1. Open `Parts.xcodeproj` in Xcode.
2. Select the **Parts** scheme and an iPhone simulator, then Run (⌘R).
3. For a physical iPhone, choose your development team under **Signing & Capabilities** and select your device. The app supports iOS 17 and later.
4. Paste a YouTube link and tap **Watch in parts**, or try the sample video.

Tap Play below the YouTube player to begin if playback does not start automatically. Swipe in the area below the player to move between parts, use the navigation buttons, or choose **All parts**. Each part automatically loops back to its own start until you navigate away. The play/pause button and seek bar below the video control only the current part. The last part may be shorter than a minute. Progress and the video library are saved locally; long-press a library entry to remove it.

## Scope

This version segments playback of the original video. It does not download, render, or export clips. The portrait interface preserves the original video framing. YouTube’s controls are hidden using supported player parameters; native controls sit below the video. Parts use fixed 60-second boundaries rather than detecting sentences or scenes. Link input supports watch, short, embed, live-recording, and youtu.be URLs. Live streams and videos whose creators disable embedding cannot be played as parts. Internet access is required. iOS Share Sheet importing and in-app YouTube search are not included yet.

## Checks

```sh
swift test
node --test Tests/PlayerTests/player.test.cjs
xcodebuild -project Parts.xcodeproj -scheme Parts -sdk iphonesimulator \
  -configuration Debug -derivedDataPath /tmp/parts-build CODE_SIGNING_ALLOWED=NO build
```

Swift tests cover link validation, part boundaries, and persisted progress. Node tests execute the actual bundled player script with a simulated YouTube API to check looping boundaries, navigation, final parts, pause, seeking, and resume.

During initial implementation, all six tests passed and all iOS Swift sources passed a direct compiler type check against the installed simulator SDK. Full Xcode build and simulator playback could not be verified: the local Xcode installation fails loading `IDESimulatorFoundation` due to an incompatible `DVTDownloads` framework, and the environment blocks CoreSimulator service access. Real YouTube playback still needs a simulator or device smoke test.

## Implementation

- `Parts/Core/Video.swift`: link parsing, part calculations, saved-video model.
- `Parts/App/`: SwiftUI screens, local library, WKWebView bridge.
- `Parts/Resources/player.html`: YouTube IFrame API player and segment playback.

The WebView supplies the app’s bundle identifier as its HTTPS base URL and player origin, following [YouTube’s embedded player identification guidance](https://developers.google.com/youtube/terms/required-minimum-functionality#api-client-identity-and-credentials). Playback uses the [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference).
# youtube-to-tiktok
# youtube-to-tiktok
# youtube-to-tiktok
# youtube-to-tiktok
