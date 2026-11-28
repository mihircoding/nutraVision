# Install NutraVision on your iPhone

What the Mac needs: Xcode 26, an Apple Developer account signed in to Xcode, XcodeGen
(`brew install xcodegen`, or a copy at `~/.local/xcodegen-dl`) and this repo. The git-ignored
`ios/Config.local.xcconfig` holds your team, bundle id and Supabase project (`scripts/configure-ios.sh` writes it).

**Backend:** already connected to your Supabase project. For photo scanning and full-speed food search, add
the two API keys first ([BACKEND-SETUP.md](BACKEND-SETUP.md)). The iPhone needs **iOS 17.2 or later**.

On the paid Developer Program the installed app keeps working for a year. (Free Apple IDs expire after 7 days,
and may not be able to sign the HealthKit capability.)

---

## Option A: one command (recommended)

1. **Connect the iPhone** to the Mac with a cable. Unlock it. If it asks "Trust This Computer?", tap **Trust**
   and enter the passcode.
2. **Turn on Developer Mode** (once per phone):
   **Settings > Privacy & Security > Developer Mode** > on > **Restart**. After the restart, unlock and tap
   **Turn On**.
   *No Developer Mode row? Open Xcode once with the phone connected (step 1 of Option B) and it appears.*
3. In Terminal run:

```bash
~/Desktop/NutraVision/scripts/install-on-iphone.sh
```

If more than one phone is connected, add the name:

```bash
~/Desktop/NutraVision/scripts/install-on-iphone.sh "My iPhone"
```

The first run takes 3 to 5 minutes. Xcode registers the app with your team and creates a signing profile. When
it prints `Done`, NutraVision is open on the phone.

Run the same command again after any code change to update the app. Your data stays: it lives in Supabase, not
on the phone.

## Option B: from Xcode

1. Generate and open the project:

```bash
cd ~/Desktop/NutraVision/ios && ~/.local/xcodegen-dl/xcodegen/bin/xcodegen generate && open NutraVision.xcodeproj
```

2. In the toolbar at the top, pick the **NutraVision** scheme and your iPhone as the run destination.
3. Click the **NutraVision** project > **NutraVision** target > **Signing & Capabilities**. Check that Team shows
   your team and "Automatically manage signing" is on.
4. Press **⌘R**.

**Wireless after the first time:** Xcode > Window > **Devices and Simulators** > pick the phone > check
**Connect via network**. From then on the phone only needs to be on the same Wi-Fi.

---

## First launch on the phone

- **Sign in** with a demo account (`maria@nutravision.demo` / `demo1234`) or create your own.
- The app asks for permissions only when a feature needs them: **Camera** (barcode and photo scan),
  **Microphone + Speech** (Glasses Mode), **Bluetooth** (glasses), **Health** (More > Apple Health).
  If you tap "Don't Allow" by mistake: **Settings > NutraVision** turns it back on. Health permissions are under
  **Settings > Health > Data Access & Devices > NutraVision**.

## Meta Ray-Ban glasses (optional)

1. Pair the glasses in the **Meta AI** app as usual.
2. Meta AI app > **Devices** > your glasses > **Developer Mode** > on. NutraVision isn't registered with Meta,
   and Developer Mode is what lets it connect.
3. In NutraVision: **More > Glasses** > **Connect**, approve in Meta AI, then start **Glasses Mode**.
4. Keep the phone **unlocked** during Glasses Mode (iOS pauses the camera stream on a locked phone).

## Sharing it with someone else

Their iPhone can't use your build directly. Two options:

- **TestFlight** (best): in App Store Connect create an app with bundle id `com.mihircoding.nutravision`. Then in
  Xcode choose **Product > Archive > Distribute App > TestFlight Internal Only** and add them as a tester.
- **Their own device on your account**: connect their phone to this Mac and run the install script with their
  phone's name. Your paid team allows up to 100 iPhones a year.

## Troubleshooting

| Message | Fix |
|---|---|
| `No connected iPhone found` | Use a data cable (not charge-only), unlock the phone, tap Trust. Run `xcrun devicectl list devices`: the phone's state should not say `unavailable`. |
| `Developer Mode is off` | Step 2 of Option A. |
| `Failed to register bundle identifier` / "cannot be registered to your development team" | The id is taken. Pick another, then rerun the install script: `scripts/configure-ios.sh --bundle-id com.mihircoding.nutravision2` |
| `No Account for Team` / `No signing certificate` | Xcode > Settings > **Accounts**: sign in with your developer Apple ID, then run the script again. |
| `Device is busy (Preparing iPhone for development)` | Wait 1 to 2 minutes with the phone unlocked and connected, then retry. |
| "Could not launch, the device is locked" | Unlock the phone and open the app from the home screen. It is installed. |
| The app shows "This build has no Supabase project" | Finish BACKEND-SETUP.md step 7, then rerun the install script. |
