# react-native-screen-record

Record a view — or the whole app window — into an MP4, animations and all. Made for saving animated content (stories,
stickers, Skia drawings, charts) as video.

- H.264 MP4 without sound, up to 1080 px wide by default, at up to 30 fps.
- Records what's on screen: native views, Skia and other GPU-drawn views, animations from any thread.
- iOS and Android, no permissions needed.

## Requirements

- React Native with the New Architecture (a TurboModule; tested with React Native 0.86 and Expo SDK 57).
- iOS 15.1 or newer.
- Android 8.0 (API 26) or newer to record; on older versions the app still runs and recording rejects with
  `E_UNSUPPORTED`.

## Installation

```sh
npx expo install react-native-screen-record
# or
npm install react-native-screen-record
```

Then rebuild the app (`npx expo run:ios` / `run:android`, or a new development build): the library has native code, so
it doesn't run in Expo Go. No config plugin is needed. In a React Native app without Expo, run `pod install` in `ios/`.

## Usage

```tsx
import { useRef, type ComponentRef } from 'react';
import { View } from 'react-native';
import { recordView } from 'react-native-screen-record';

function Story() {
  const ref = useRef<ComponentRef<typeof View>>(null);

  async function save() {
    const uri = await recordView(ref, { durationMs: 5000 });
    // `uri` is a file:// URI in the app's cache: move, share or save it to the gallery.
  }

  return (
    <View ref={ref} collapsable={false}>
      {/* … */}
    </View>
  );
}
```

`collapsable={false}` keeps a plain `View` from being flattened away on Android, so there's a native view to record.

### API

#### `recordView(target, options?): Promise<string>`

Records the view `target` (a ref from `useRef`, or a native tag) and resolves to the video's `file://` URI once it's
written. The view has to stay on screen while it's recorded.

#### `recordScreen(options?): Promise<string>`

Records the whole app window.

#### `stopRecording(): void`

Ends the recording in progress early; its promise resolves with what was recorded until then. With `durationMs: 0`,
this is how a recording ends.

#### `isRecording(): boolean`

#### Options

| Option       | Default      | Description                                                     |
| ------------ | ------------ | --------------------------------------------------------------- |
| `durationMs` | `5000`       | How long to record. `0` records until `stopRecording()`.        |
| `width`      | `1080`       | Width of the video in pixels; the height keeps the proportions. |
| `fps`        | `30`         | Frames per second, at most.                                     |
| `bitRate`    | `10_000_000` | Average bit rate in bits per second.                            |

### Errors

The promise rejects with an error whose `code` is one of:

| Code            | When                                                                |
| --------------- | ------------------------------------------------------------------- |
| `E_BUSY`        | A recording is already in progress: one runs at a time.             |
| `E_NO_VIEW`     | The view isn't there (unmounted, or flattened away on Android).     |
| `E_RECORDING`   | Recording failed: the view has no size, no frame was recorded, etc. |
| `E_UNSUPPORTED` | Android older than 8.0.                                             |

If the ref is empty when `recordView` is called, it rejects without a code, before reaching the native side.

## How it works

- **iOS:** a `CADisplayLink` ticks with the screen, at most `fps` times a second. Each tick, the view's hierarchy is
  drawn (`drawViewHierarchyInRect:afterScreenUpdates:NO`, which includes Metal-backed views; through its layer if it
  isn't on screen) into a pixel buffer of an `AVAssetWriter` and appended with the time since the recording started.
- **Android:** `PixelCopy` copies the part of the window the view covers, which is drawn onto the input surface of a
  hardware H.264 encoder (`MediaCodec`); `MediaMuxer` writes the MP4. If no encoder takes the requested size, it falls
  back to 720 px wide.

Frames carry the time they were captured, so the video plays at the right speed even when a slow device captures
fewer frames than asked.

### Things to know

- On Android, whatever is drawn on top of the view (toolbars, toasts, the keyboard) is recorded too, since it's copied
  from the screen. Hide it while recording.
- Rounded corners or other clipping by a parent show up as black on Android for the same reason.
- No audio.
- Drawing every frame takes time on the main thread: big views at a high resolution may record at less than `fps`,
  especially on the iOS simulator.

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
