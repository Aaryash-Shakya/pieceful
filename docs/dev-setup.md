# Development setup

Everything needed to build and run Pieceful on the owner's machine, and how to remove all of it again. It is written for one machine, CachyOS (Arch-based, kernel 7.2.x), but the steps are plain commands, so they work on any Arch-based system.

The goal is a setup that is reproducible and leaves nothing behind. Every install lists what it adds and where, and the removal section reverses each step.

Checked on 2026-10-22: the machine had no Java, no Godot, no Android SDK, and none of `~/.android`, `~/.gradle`, `~/Android`, `~/.config/godot` or `~/.local/share/godot`. Git, curl, unzip and sha256sum were already installed.

## Requirements

| Component | Version | Source | Lives in |
|---|---|---|---|
| Godot | 4.7.2 | Arch `extra` package `godot` | system packages, plus `~/.config/godot`, `~/.local/share/godot`, `~/.cache/godot` |
| JDK | 17 | Arch `extra` package `jdk17-openjdk` | `/usr/lib/jvm` |
| Android command-line tools | `commandlinetools-linux-15859902_latest.zip` | Google, downloaded by hand | `~/Android/Sdk/cmdline-tools/latest` |
| Android platform-tools (`adb`) | 35.0.0 or later | `sdkmanager` | `~/Android/Sdk/platform-tools` |
| Android build-tools | 35.0.1 | `sdkmanager` | `~/Android/Sdk/build-tools` |
| Android platform | android-35 | `sdkmanager` | `~/Android/Sdk/platforms` |
| Godot Android export templates | same as the Godot version | the Godot editor | `~/.local/share/godot/export_templates` |
| Debug keystore | n/a | created with `keytool` | `~/.android/debug.keystore` |

The versions above come from Godot's Android export page for the 4.7 docs and from Google's download page, both read on 2026-10-22. The page also lists CMake 3.10.2.4988404 and NDK r28b (28.1.13356709). It does not say whether a plain export needs them. We start without them, since the NDK is large, and add them if the export asks for them. If we do, add them to this table.

Godot's docs say Linux users should not take the SDK from their distribution's repositories, as it is often out of date. That is why the SDK is installed from Google. For the same reason, **do not install the `android-tools` package.** `adb` comes from the SDK's platform-tools, so there is only one copy.

Packages that pacman will add with Godot and JDK 17, taken from a dry run on 2026-10-22: `godot`, `embree`, `libspeechd`, `libsquish`, `libwslay`, `miniupnpc`, `openxr`, `jdk17-openjdk`, `java-runtime-common`, `java-environment-common` and `libnet`. These can change over time, so recheck with the dry run in the removal section.

Not needed: Docker, Android Studio, Gradle, Kotlin, Flutter.

## Install

Steps A and I need your password. Run those with the `!` prefix.

**A. Godot and JDK 17**

```
sudo pacman -S --needed godot jdk17-openjdk
```

**B. Android command-line tools**

The zip is about 180 MB. The expected SHA-256 is `4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583` (from Google's download page). If the checksum command fails, stop and do not unpack the file. The download address below follows Google's usual pattern and was not shown on the page, so if it fails, get the link from `developer.android.com/studio`.

```
mkdir -p ~/Android/downloads ~/Android/Sdk/cmdline-tools
cd ~/Android/downloads
curl -fLO https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip
echo "4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583  commandlinetools-linux-15859902_latest.zip" | sha256sum -c -
unzip -q commandlinetools-linux-15859902_latest.zip -d unpacked
mv unpacked/cmdline-tools ~/Android/Sdk/cmdline-tools/latest
```

**C. SDK components and licences**

```
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$HOME/Android/Sdk "platform-tools" "build-tools;35.0.1" "platforms;android-35"
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$HOME/Android/Sdk --licenses
```

Accepting the licences means you agree to Google's terms. Read them first. Acceptance is stored in `~/Android/Sdk/licenses`.

**D. Debug keystore**

Godot's Android page does not say how to create one, so this uses the standard Android debug values. A debug keystore signs test builds only and is not a secret. Confirm the path in Godot's editor settings in step E.

```
mkdir -p ~/.android
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore ~/.android/debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
```

**E. Godot editor settings**

Open Godot, then Editor, Editor Settings, Export, Android. Set:
- Java SDK Path: `/usr/lib/jvm/java-17-openjdk`
- Android SDK Path: `/home/aaryash/Android/Sdk`
- The debug keystore fields, if present in this version: `~/.android/debug.keystore`, user `androiddebugkey`, password `android`.

**F. Export templates**

In Godot, open Editor, Manage Export Templates, and download and install the templates for the exact running version. This menu path is from memory, so use the editor's own prompt if it differs.

**G. The phone**

On the Nothing Phone (4a): turn on Developer options (tap the build number seven times in Settings, About phone), then turn on USB debugging. Plug it in and accept the prompt on the phone.

If `adb devices` later shows the phone as unauthorised or without permissions, the udev rules are missing. The Arch `extra` repo has an `android-udev` package for that. Install it only if needed, and add it to this file and the removal list when you do.

**H. Verify**

```
java -version
godot --version
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$HOME/Android/Sdk --list_installed
~/Android/Sdk/platform-tools/adb devices
```

You should see Java 17, Godot 4.7.2, the three installed SDK packages, and the phone listed as a device.

**I. Optional, to type `adb` anywhere**

Add `~/Android/Sdk/platform-tools` to your PATH in your own shell configuration. Nothing here edits your shell files for you.

**J. Tidy up after the install**

The downloaded zip is no longer needed: `rm -r ~/Android/downloads`.

## Where everything lives

- `~/Android/`: the Android SDK and the download folder.
- `~/.android/`: the debug keystore, and the adb keys that `adb` creates the first time it runs.
- `~/.config/godot/`: Godot's editor settings, including the SDK and JDK paths.
- `~/.local/share/godot/`: Godot's export templates.
- `~/.cache/godot/`: Godot's cache.
- `~/.gradle/`: only appears if a Gradle build is used later. Not created by the steps above.
- In the project folder, generated and ignored by git: `.godot/`, `android/` and any `*.apk` or `*.aab` files.
- The release keystore is kept outside the repository, in a location chosen when it is created. Add it to this list then.

## Remove everything

Do this in order. It deletes your Godot settings and the SDK. It does not touch the project folder.

1. **Back up the release keystore first, if one exists.** Losing it means existing users can never update the app. The commands below do not delete it, but do not add it to them.
2. Delete the SDK and download folder: `rm -r ~/Android`
3. Delete the Android debug keys: `rm -r ~/.android`
4. Delete Godot's settings, templates and cache: `rm -r ~/.config/godot ~/.local/share/godot ~/.cache/godot`
5. If Gradle was used: `rm -r ~/.gradle`
6. Remove the packages and the dependencies that only they needed: `sudo pacman -Rns godot jdk17-openjdk`
7. If you installed `android-udev`: `sudo pacman -Rns android-udev`
8. Check for leftovers. This lists orphans, packages nobody needs. Read the list and remove only what you recognise as part of this setup: `pacman -Qdtq`
9. On the phone, open Developer options and tap Revoke USB debugging authorisations, then turn off USB debugging and Developer options.
10. Optionally clear generated project files: `rm -r .godot android` and any `*.apk` files in the project folder.

To confirm it is clean, run the same checks as the baseline above. `command -v godot java adb` should print nothing, and the folders listed under "Where everything lives" should not exist.

## Keeping this reproducible

- Pin versions in this file and change them only on purpose. When Godot is updated, update the Godot version here and re-check the SDK versions on Godot's Android export page for that version.
- Record the Godot version in the project when it is created.
- If a step fails or needs a different command, fix it here in the same commit.
- A later improvement is to turn steps B and C into a script in the repository, so the whole setup is one command. The commands are already written in a form that can be copied into a script.

## Not verified

The exact Godot menu paths and the names of the keystore fields in the editor settings, whether a plain export needs CMake and the NDK, whether Godot 4.7 supports a minimum Android version that includes the Galaxy On7 Pro, and the exact download address for Google's tools. Fix this file as each one is confirmed.
