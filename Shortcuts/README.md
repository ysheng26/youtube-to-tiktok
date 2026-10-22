# Watch in Parts

Parts supports two Share Sheet actions:

- **Save to Parts** is the app’s existing Share Extension. It saves the video to the library and returns to YouTube or Safari.
- **Watch in Parts** is a shortcut you create once. It launches Parts using `parts://watch?url=…` and opens the chosen video. It also saves the video to the library.

Rebuild and reinstall Parts before using the shortcut so iOS registers the `parts` URL scheme.

## Create the shortcut on iPhone

1. Open **Shortcuts**, create a shortcut, and name it **Watch in Parts**.
2. In its details, turn on **Show in Share Sheet**. Accept **URLs**, **Text**, and **Safari Web Pages**.
3. Add **Get URLs from Input**, with **Shortcut Input** as the input.
4. Add **Get Item from List**, selecting **First Item** from the URLs.
5. Add **URL Encode**, encoding the first item. Use **Encode**, not Decode.
6. Add a **Text** action containing `parts://watch?url=` followed immediately by the **URL Encoded Text** magic variable from the previous action. Insert the variable using Shortcuts’ variable picker; don’t type its name as literal text.
7. Add **Open URLs**, with the Text action’s output as its input.

The final action sequence is:

```text
Shortcut Input
  → Get URLs
  → Get First Item
  → URL Encode
  → Text: parts://watch?url=[URL Encoded Text]
  → Open URLs
```

Share a YouTube video, scroll to **Watch in Parts**, and select it. iOS may ask permission to open Parts the first time. The shortcut runs on your iPhone and sends the URL to Parts; there is no third-party relay service. With no valid YouTube link, Parts shows an error rather than opening an unrelated video.

The **Save to Parts** extension remains available independently of this shortcut. Saved videos do not automatically start playing when you next open the app. **Watch in Parts** goes directly to the player, resumes an existing video’s progress, and replaces an already-open player after saving its progress.

## Source and signing

`Watch in Parts.source.plist` records the shortcut’s five actions and Share Sheet input types. It is an unsigned source template, not a one-tap import. Its execution has not been verified in Shortcuts here. The manual recipe above is the primary setup path.

The macOS signing tool fails in this environment even on an Apple-supplied workflow, so an importable signed `.shortcut` could not be produced. To try signing the source locally on your Mac:

```sh
shortcuts sign --mode anyone \
  --input 'Watch in Parts.source.plist' \
  --output 'Watch in Parts.shortcut'
```

If successful, send the signed file to your iPhone and open it in Shortcuts, then inspect its actions before adding it. No signed file or iCloud installation link is included in this repository.

## Verification on a device

- Cold launch: quit Parts, share a YouTube video with **Watch in Parts**, and confirm the correct player opens.
- Warm launch: while watching one video, switch to YouTube and share another. Confirm Parts saves the old progress and opens the new video.
- Share the same video twice using **Watch in Parts** and confirm both invocations work.
- Use **Save to Parts**, then manually open Parts and confirm the video is in the library without being forced into playback.

Scheme smoke test from a Mac connected to a running simulator:

```sh
xcrun simctl openurl booted 'parts://watch?url=https%3A%2F%2Fyoutu.be%2Faqz-KE-bpKQ'
```

References: [Apple: Share Sheet shortcuts](https://support.apple.com/guide/shortcuts/apd163eb9f95/ios), [Apple: custom URL schemes](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app).
