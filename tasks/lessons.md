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

## Signing and keychain prompts for local test runs (2026-07-10)

Repeated xcodebuild runs prompted John's keychain for the signing key on every build, which he rightly flagged as annoying. Facts learned: clicking "Always Allow" on the prompt (with password, once per key) silences it permanently; there are two keys (Apple Development for test builds, Developer ID Application for releases). Ad-hoc signing (CODE_SIGN_IDENTITY="-") avoids the keychain entirely and is fine for unit test bundles, but it BREAKS UI tests: the ad-hoc-signed app loses its automation/accessibility identity and 5 of 7 UI tests fail on launch. Rule: unit tests may run ad-hoc; UI tests must use the real identity; tell John to Always Allow instead of hammering builds through prompts.

## Codex sessions stop reporting to AgenticGlow after a hooks.json repair (2026-07-12)

**What happened:** John has multiple hook-based menu bar apps installed (AgenticGlow, plus two others called Klarity and Sessionlet) that all write entries into the same `~/.codex/hooks.json` and `~/.claude/settings.json`. At some point AgenticGlow's managed entries were missing from `~/.codex/hooks.json` entirely (helper binary at `~/Library/Application Support/AgenticGlow/bin/` was also gone), so no Codex `SessionStart`/`UserPromptSubmit`/etc. events ever reached AgenticGlow and the app showed "No Active Sessions" for Codex even with sessions running. Repairing the integration through AgenticGlow's Setup window correctly rewrote `hooks.json` with AgenticGlow's entries restored alongside the other apps' — but sessions still didn't show up afterward.

**Root cause of the second half:** Codex's `app-server` background process reads `~/.codex/hooks.json` once, at its own process startup, and keeps it in memory for the life of the process. It does not hot-reload on file change and does not re-read per session or per turn. Every currently-running Codex process (`app-server`, `Codex (Renderer)`, etc.) had started *before* the hooks.json repair, so none of them ever saw the fixed config. A `hooks.json` write is invisible to Codex until every Codex/ChatGPT process is fully quit and relaunched.

**Rules:**
- When a hook-based integration (Claude Code or Codex) stops reporting events, check three things in order: (1) does the target config file (`~/.codex/hooks.json` or `~/.claude/settings.json`) actually contain this app's managed entries — grep for the marker string (`--agenticglow-hook`); (2) does `~/Library/Application Support/AgenticGlow/bin/agenticglow-event` exist; (3) is there evidence of the events actually arriving — check `~/Library/Application Support/AgenticGlow/Sessions/*.json` for a file newer than the fix, cross-referenced against `sourceProcessID`/`sourceProcessStartedAt` in the JSON against `ps` to confirm the reporting process started *after* the config was last written.
- After any repair that rewrites `~/.codex/hooks.json`, Codex (the ChatGPT app) must be fully quit (`Cmd+Q`, confirm no `codex`/`Codex Framework`/`ChatGPT` processes remain in `ps aux`) and relaunched before new hook events will fire. Simply closing session windows or restarting AgenticGlow is not enough — Codex is the one caching the config.
- Multiple hook-consuming apps (AgenticGlow, Klarity, Sessionlet) share the same `hooks.json`/`settings.json` — when diagnosing, don't assume an empty-looking managed-entries block means all integrations are broken; check specifically for this app's marker, since another app's entries can be present and healthy while this one's are missing.

## A stale duplicate install can masquerade as a live rendering bug (2026-07-14)

**What happened:** John reported Claude session rows showing Codex's blue color. Reading `SessionRowView.color`, `ProviderColor`, `NormalizedEvent` decoding, and `SessionResolver` all checked out correct — every piece of code read cleanly. The dispositive test was reading the row's live `AXIdentifier` via the accessibility API (it bakes in `session.id` = `"provider:sessionID"` directly from the bound model), which proved the underlying data was genuinely `provider: claude`. Since correct data was rendering with the wrong color, and *both* a Claude and a Codex row rendered as the exact same shade of blue (not just one mislabeled), the pattern pointed away from a data bug entirely. `ps aux | grep -i agenticglow` then found the real cause: `/Applications/AgenticGlow-0.2.0.app`, a build from 2026-07-05, still running (uptime: hours). Per-provider row coloring (`ProviderColor`, commit `34b81db`) shipped 2026-07-09 — four days after that build. The old build predates the feature entirely, so every active row renders with its old default color regardless of provider. A stray Login Item was also found pointing at a Debug build path in Xcode's DerivedData rather than either `/Applications` copy — leftover from development, silently relaunching a debug build at every login.

**Rule:** When a visual/behavioral bug reads as "the code is right but the screen is wrong," check for a second running instance of the *same app* before hunting further in source: `ps aux | grep -i <appname>` and `ls -la /Applications | grep -i <appname>` for duplicate bundles. `tell process "<Name>"` in AppleScript/System Events resolves ambiguously by display name — if two processes share it, you may be scripting the wrong one without any error. Also check Login Items (`osascript -e 'tell application "System Events" to get {name, path} of every login item'`) for stale paths (an old `/Applications/App-X.Y.Z.app`, or worse, a DerivedData debug build) left over from a previous install or dev session.

## A shared long-lived process defeats process-liveness staleness checks (2026-07-13)

**What happened:** John reported two identical-looking "Permisight · Thinking" Codex entries in the popover. One was a live session; the other was a conversation that finished 7+ hours earlier but never sent its `stop` hook event. `SessionResolver`'s only staleness signal for an active-phase session was "is `sourceProcessID` still alive," and Codex's `app-server` is a single process that backs every conversation you open that day — it never exits between tasks. So "process alive" was always true, and the orphaned session displayed as "Thinking" forever (would have persisted up to the 24h file-retention ceiling).

**Fix:** Added a time-based fallback independent of process liveness: `thinking`/`usingTool` sessions roll over to Idle after 30 minutes without an update (`SessionResolver.staleActiveDuration`), regardless of whether the backing process is alive. `permission` phase is exempt — a pending approval can legitimately wait a long time for the user.

**Rule:** When a staleness or liveness check keys off a process ID, verify first whether that process is dedicated to one session or shared across many (`ps -p <pid>` plus checking how many session files reference the same PID). A shared process makes "is it alive" meaningless as a per-session signal; you need a time-based or event-based fallback alongside it. Documented in `docs/integrations.md` under "One Process Backs Every Session."

## 2026-07-12: Screen captures at the lock screen show only wallpaper

- `screencapture` at the macOS lock screen returns the displays with no menu bar, windows, or dock, so pixel verification silently sees nothing without any error. Before concluding an icon or window is missing, check lock state: `CGSessionCopyCurrentDictionary()` contains `CGSSessionScreenIsLocked = 1` while locked (the key disappears when unlocked). Poll for unlock and resume instead of debugging phantom rendering failures.
- To find a status item without pixel hunting, ask accessibility: `tell process "AgenticGlow" to get position of menu bar item 1 of menu bar 2` gives global top-left coordinates; map them to a display via NSScreen frames (origins in this setup: LG at x -3840, BenQ at x -1920, main U2790B at 0, points).

## Deliberately launching a second same-named instance breaks AppleScript targeting too (2026-07-14)

**What happened:** Live-verifying the Remove context menu required a debug/fixture build, so I launched it alongside the already-running production AgenticGlow to test without disrupting John's session. Even though `first process whose unix id is <pid>` correctly found the fixture process for read-only queries (position, description), `click`/context-menu actions dispatched against it kept landing on the production instance's popover instead — the exact ambiguity documented in "A stale duplicate install can masquerade as a live rendering bug," except self-inflicted on purpose this time rather than a leftover stale install.

**Rule:** The duplicate-instance/`tell process "<Name>"` ambiguity applies even when the second instance is intentional and short-lived (e.g. a debug build launched for fixture testing). Don't try to disambiguate two same-named running processes for UI-scripted actions by PID alone — quit whichever instance you're not testing first, verify with `ps aux | grep -i <appname>` that exactly one remains, run the test, then relaunch the other. Read-only accessibility queries (position, description, identifier) can resolve correctly by PID even while write actions (click, AXShowMenu, AXPress) still hit the wrong instance, so a clean query result is not proof the next action will target the right process.

## Session card redesign: the glow and the usage bars are frozen (2026-07-16)

John approved the redesigned session-card mockup (failure state, per-row live indicator, tool-category icons, tap/hover-to-expand detail) from `docs/session-redesign-research.md`, but was explicit: he does not want the glow effect or the usage bars changed as part of this work.

**Rule:** When implementing the session card redesign, treat `Sources/AgenticGlowApp/MenuBar/LiquidGlassSurface.swift`, the `PopoverAura` view in `SessionListView.swift`, `AllowanceSectionView.swift`, and `AllowancePresentation.swift` as frozen. Any change to those files is out of scope for this work unless John says otherwise.

## When matching a specific reference image for an icon, render the real candidate first (2026-07-17)

**What happened:** John shared a reference image of a brain icon and said "the brain is sideways." My preview had used Tabler's `ti-brain` icon (a front/top symmetric view) as a stand-in for the real SF Symbol, assuming the two icon sets looked similar enough to compare shapes. They didn't: the actual SF Symbol named `brain` is already drawn in lateral/side profile, much closer to John's reference than the Tabler stand-in was. The mismatch was in my preview, not in the real icon I was planning to ship.

**Rule:** When a design decision hinges on a specific glyph's exact shape (not just its animation or color), don't approximate it with a similarly-named icon from a different icon set for a comparison mockup. Render the actual candidate (e.g. a tiny AppKit script calling `NSImage(systemSymbolName:)` and writing a PNG) and inspect it directly before presenting it to John, or before building the real preview around it. This is fast (a few seconds via `swift script.swift`) and removes an entire round of back-and-forth caused by a preview that didn't represent the real thing.

## Stop elaborating once John says "you're overcomplicating this" (2026-07-17)

**What happened:** After John picked a brain icon idea, I kept proposing progressively more elaborate animation treatments (radiating rays, chasing dot waves) across several rounds of visual previews, each time only partially matching what he wanted. He eventually said "You are making this way too difficult. Just go with the original option A," referring back to the very first, simplest option shown several messages earlier.

**Rule:** After presenting visual options, if John's next answer describes something more elaborate than what shipped-quality simplicity calls for, it's fine to show ONE more refined preview, but if that still doesn't land, default back to the simplest previously-shown option rather than inventing a third or fourth variant. Watch for explicit "too difficult" / "too complicated" language as a hard stop signal, not a cue to keep iterating.

## `ImageRenderer` cannot render `List`/`ScrollView` content, even off-screen (2026-07-17)

**What happened:** Needed a screenshot of a SwiftUI row to verify an icon change, but the real popover window would not reliably appear via menu-bar-click automation in this environment (same flakiness as the earlier Codex-activation problem, this time affecting our own app's window). Tried rendering the full `SessionListView` via `ImageRenderer` as a workaround — it produced an image with the header text but a blank body where the session rows should have been, because the view's row list is a `List`/`ScrollView`, and `ImageRenderer` does not lay out that content without a real attached window.

**Rule:** When `ImageRenderer` output is missing List/ScrollView content, render the specific row/component view directly (e.g. `SessionRowView` in a plain `VStack`, not the whole scrollable container) instead of trying to force the full screen to render. This sidesteps window-visibility automation entirely and is more reliable than screenshotting a live window when menu-bar-click automation is flaky. Any such debug scaffolding added to `AppDelegate.swift` for this purpose must be reverted (`git checkout`) immediately after capturing, since it is not part of the shipped feature.
