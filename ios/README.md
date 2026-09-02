# GodsEye iOS bootstrap

This is the first native iOS shell for the fork.

The goal of this milestone is intentionally small:

1. Keep the existing Vite/Cesium app unchanged.
2. Run it from the Mac during development.
3. Render it inside a native SwiftUI iPhone application with `WKWebView`.
4. Establish a Swift ↔ JavaScript bridge.
5. Confirm that Cesium, WebGL and live layers behave acceptably on iPhone.

## Requirements

- macOS with Xcode
- Node.js version required by the repository
- Homebrew
- XcodeGen

Install XcodeGen:

```bash
brew install xcodegen
```

## 1. Start the existing web application

From the repository root:

```bash
npm install
npm run dev -- --host 0.0.0.0 --port 4173
```

For the iOS Simulator, `localhost:4173` works.

For a physical iPhone, discover the Mac LAN IP, for example:

```bash
ipconfig getifaddr en0
```

Both devices must be on the same network.

## 2. Generate the Xcode project

```bash
cd ios
xcodegen generate
open GodsEyeIOS.xcodeproj
```

Choose your Apple Development Team in Signing & Capabilities.

## 3. Simulator

No extra configuration is required. The default URL is:

```text
http://localhost:4173
```

Run the app. The small native status bar should change from:

```text
CONNECTING…
```

to:

```text
GEV CONNECTED
```

once `window.__godsEyeView.viewer` exists.

## 4. Physical iPhone

In Xcode:

Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables

Add:

```text
GEV_DEV_SERVER_URL=http://YOUR_MAC_IP:4173
```

Example:

```text
GEV_DEV_SERVER_URL=http://192.168.1.20:4173
```

Run on the iPhone and accept the local-network permission if iOS requests it.

## Bridge

At document start, the native shell injects:

```js
window.__GEV_IOS__ = true;

window.GEVNative.postMessage("event-name", {
  example: "payload"
});
```

Swift can also execute commands against the existing runtime because `src/main.js`
publishes `window.__godsEyeView`.

The first bridge already contains:

- runtime readiness probing
- `flyTo(latitude:longitude:altitudeMeters:)`
- a preliminary `setLayer(id:enabled:)`

The layer method intentionally uses a fallback event because we should confirm the
current public `DataLayerManager` API before coupling native code to an internal
method.

## Next milestone

After this bootstrap works on an actual iPhone:

1. Add a small web-side `src/iosBridge.js`.
2. Define stable commands:
   - `flyTo`
   - `setLayer`
   - `trackEntity`
   - `stopTracking`
   - `setMapStyle`
   - `getSelection`
3. Hide the web desktop/mobile chrome when `window.__GEV_IOS__` is present.
4. Rebuild those controls with SwiftUI.
5. Move secret-bearing provider routes to a production backend.
6. Add Core Location and native "near me" actions.
