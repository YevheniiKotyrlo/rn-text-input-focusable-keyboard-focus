# Android: a `TextInput` takes hardware-keyboard focus even with `tabIndex={-1}` or `focusable={false}`

React Native 0.90.0-nightly-20261120-bbfd39149, from the [React Native reproducer template](https://github.com/react-native-community/reproducer-react-native). `ReproducerApp/App.tsx` renders, top to bottom:

- a `Pressable`, "first button";
- `<TextInput accessibilityLabel="input with tabIndex -1" tabIndex={-1} />`;
- `<TextInput accessibilityLabel="input with focusable false" focusable={false} />`;
- a `Pressable`, "second button".

Neither input should take keyboard focus: Tab, Shift+Tab and the D-pad or arrow keys should move between the two buttons only.

## Steps

By hand, on an Android device or emulator with a hardware keyboard:

1. Build and install the release APK: `cd ReproducerApp && yarn install && cd android && ./gradlew assembleRelease && adb install -r app/build/outputs/apk/release/app-release.apk`.
2. Open the app and press Tab repeatedly. A focused button gets a pink border; focus also lands on each input.
3. Press the down arrow (D-pad Down) from the first button: focus moves to the first input, then the second, then the second button.

Without a keyboard: `adb shell input keyevent KEYCODE_TAB`, `adb shell input keycombination KEYCODE_SHIFT_LEFT KEYCODE_TAB` (Android 12 or newer) and `adb shell input keyevent KEYCODE_DPAD_DOWN`.

Scripted: `./reproduce.sh`, with one Android device attached, builds and installs the app, then for each of Tab, Shift+Tab (Android 12 or newer) and D-pad Down starts the app afresh, presses the key six times and reads which view holds focus after each press from `uiautomator dump`. It exits 1 while either input takes focus, 0 once Tab and Shift+Tab reach both buttons, D-pad Down the second one, and none of them an input, and 2 when a walk misses a button it should reach, another view takes focus or a step fails.
