# Fix: Dark Mode popover too light (2026-07-05)

Bug report from John: "Dark Mode is too light." Reproduced on macOS 27 in Dark Mode:
the popover glass is nearly transparent, desktop content bleeds through, and the
popover reads light gray instead of dark.

Root cause: on macOS 26+ `SessionListView` uses `Color.clear` as the background,
relying only on the system Liquid Glass popover material. No dark tint exists for
Dark Mode.

Plan (bug fix, autonomous path):

- [x] Reproduce with screenshot of live popover in Dark Mode
- [x] Add a Dark Mode scrim layer behind the popover content in SessionListView
- [x] Build three scrim strengths (A: 0.30, B: 0.45, C: 0.60), screenshot each on the real popover -> verified: side-by-side captures, signed test builds with John's Developer ID so keychain access stayed silent
- [x] Present labeled variants A/B/C to John, with recommendation B
- [x] John picked B (0.45) and clarified "too light" meant the aura border glow: he wants dark mode's aura to match light mode
- [x] Unify PopoverAura: light palette, light opacities, no blend mode, drop unused colorScheme -> verified: rebuilt app screenshot shows saturated azure/gold edges over the dark scrim
- [x] Run /code-review (8 finders + 2 verifiers) -> 2 confirmed findings: pre-macOS-26 dark mode has no scrim (reported, intentionally out of scope, cannot visually verify on this machine); magic numbers -> fixed with named constants
- [x] Tests 154/154 pass, privacy gate passes, committed locally (push pending John's OK)
