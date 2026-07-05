# InputLocker

InputLocker is a small macOS menu bar utility that keeps the current keyboard input source pinned to a selected source.

It uses macOS Text Input Source Services, not private APIs. The lock is practical rather than absolute: when macOS or an app changes the input source, InputLocker switches it back.

## Run

```sh
swift run InputLocker
```

## Build App Bundle

```sh
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
open .build/InputLocker.app
```

## Behavior

- Saves a target input source in `UserDefaults`.
- Watches frontmost app changes.
- Re-applies the target input source after app activation.
- Runs a lightweight periodic check while the lock is enabled.
- Lets you choose the target source from the menu bar menu.

## Notes

Some secure or system-owned text fields can still override third-party input methods. The app will not bypass macOS security rules.
