# Lessons

Rules learned from real mistakes in this project. Read in full at session start. Add a new entry after any correction from John.

## CI scripts must only use tools preinstalled on GitHub runners (2026-07-05)

**What happened:** `Scripts/verify-privacy.sh` used `rg` (ripgrep). It worked locally because ripgrep is installed on John's Mac via Homebrew, but GitHub's macOS runners are clean machines without it. Every push failed the CI `test` job with `rg: command not found` (exit 127), generating a failure email per push.

**Rules:**
- Any script that runs in CI must use only built-in tools: `grep`, `sed`, `awk`, `find`, `bash`, `git`, `curl`, `python3`, `xcodebuild`. No Homebrew-installed tools (`rg`, `fd`, `jq` is preinstalled on GitHub runners but verify anything else) unless the workflow explicitly installs them first.
- `grep` equivalents for ripgrep: `rg -q '\bword\b'` becomes `grep -qw word`; alternation `a|b` needs `grep -E`; fixed strings use `grep -F`; directory scans need `grep -r`.
- Exit code 127 in a CI log means "command not found." Check for missing tools before debugging anything else.
- Before adding a new CI step, ask: does this command exist on a fresh macOS runner?

## Keep GitHub Actions on current major versions (2026-07-05)

`actions/checkout@v4` triggered Node deprecation warnings on every run. Bumped to `@v5` in both `ci.yml` and `release.yml`. When a CI annotation warns about a deprecated action or runtime, bump it promptly; warnings become failures when GitHub removes the old runtime.

## Show elapsed seconds below one minute (2026-07-05)

John prefers exact elapsed seconds for active sessions under one minute. Display `54s`, for example, instead of `<1m`.

## Ambient animation must be visibly alive (2026-07-05)

The first popover aura drifted at 70 seconds per revolution and John reported "I can't see any animations" even though pixel diffing proved it was moving. Rule: ambient motion should show a clearly noticeable change within about 5 seconds of watching, while each individual moment still looks calm. Verify by capturing frames a few seconds apart, not just by confirming the animation code runs.

## Present design options as labeled visual variants in chat (2026-07-05)

When John dislikes a look, do not guess a single replacement. Render 3 or 4 labeled variants (A, B, C, D) he can see directly in the conversation and let him pick. File attachments did not display for him; inline widgets did. Also: keep color in one element per row. He asked to remove the tinted percentage text so only the bars carry the provider color.

## Confirm which element visual feedback targets (2026-07-05)

John reported "Dark Mode is too light." I read it as the whole popover surface; he meant the glowing border colors were too bright and washed out, and he wanted the dark aura to match light mode's saturated look. The surface scrim was still wanted, but the aura was the actual complaint. Rule: when John critiques a visual property (too light, too bright, too big), name the element I think he means before implementing, or present the interpretation alongside the fix so he can redirect cheaply.

## Guard new-SDK symbols with compiler checks, not just #available (2026-07-05)

`ConcentricRectangle` (macOS 26 SDK) compiled locally on Xcode 26 but broke CI, which builds with Xcode 16.4. `if #available(macOS 26.0, *)` only guards at runtime; the symbol must also exist at compile time. Wrap any API newer than the CI toolchain's SDK in `#if compiler(>=6.2)` (or the matching version) with a fallback branch. Local green is not proof: CI's Xcode is older than the local beta.

## A UI reference usually means "restyle my data," not "build a new feature" (2026-07-08)

John shared a macOS weather "Feels Like" widget (a bar with a floating pill) and asked to add "something like this." I read it as a new metric and proposed a burn-rate/pace indicator with up/down delta arrows, then built mockups for it. He corrected me: he only wanted the existing percent-left number moved into the pill, no arrows, no new math. Rule: when John shares a visual reference, lead with the simplest interpretation, applying the visual pattern to data that already exists, and confirm that before designing anything more elaborate. Show a quick mock of the literal reading first; only add new meaning if he asks for it.

## Menu bar icon: never swap the image under a symbol effect (2026-07-09)

John reported the working icon "glitching" between blue and orange. Root cause: the cross-fade rebuilt the icon image every frame while rotation ran as an SF Symbol effect on the view; every image swap restarts the effect, so the spin stuttered continuously. Also true: the menu bar ignores `contentTintColor` and flattens template images, and rotating the view (`frameCenterRotation`) fights Auto Layout until the icon vanishes. Rule: for animated status items, bake rotation and color into a single image per frame from one clock-driven task. No symbol effects, no view or layer transforms, no tint properties.

## Verify menu bar visuals on the ACTIVE display only (2026-07-09)

macOS dims menu bar content on inactive displays, and the bar's material can wash colored icons toward the bar tone there. I spent a long detour "fixing" invisible orange that was really system dimming on an inactive BenQ bar; the same wallpaper on the active main display showed the icon crisp in 37/37 frames. Rule: pixel-verify status item rendering on the display that is currently active, and confirm which DerivedData products directory the launched binary came from before trusting any visual check (a stale July 3 build cost an hour of false diagnosis).

## effectiveAppearance KVO storms with self-rendering status items (2026-07-09)

Observing `button.effectiveAppearance` to adapt icon colors re-fired from our own 30fps renders (~325 events/s measured), looping re-renders. Rule: for anything redrawn by a frame task, read environment state (like bar appearance) inside the frame task instead of observing it; changes apply within a frame and there is nothing to storm.

## Do not repeatedly trigger Keychain prompts during UI verification (2026-07-10)

Repeated app-hosted and UI-test launches of locally re-signed Debug builds caused
John to receive repeated Keychain password prompts. Rule: before visual QA or UI
testing, use an isolated in-memory credential path that cannot touch the login
Keychain, or use verification that does not launch the app host. Stop immediately
if a Keychain prompt appears. Never ask John to approve repeated prompts for a
visual-only change.

## Keep observable settings identity stable across app launch (2026-07-10)

SwiftUI created the Settings scene with the original `PreferencesStore`, but
`applicationDidFinishLaunching` replaced that object before constructing the
popover. The slider therefore updated a different store from the one rendering
the glass. Rule: app-wide observable stores passed into multiple scene or window
roots must retain one object identity for the full app lifetime. Reconfigure
backing services or defaults in place instead of replacing the observable.
