# Got done

## 2026-07-04 — Approved app icon, private release candidate, and canonical main

- Replaced the rejected application artwork with the approved Unified Spectrum icon while preserving the existing monochrome menu-bar symbol.
- Added a deterministic AppKit renderer and regenerated every required macOS app-icon raster from the verified 1024px master.
- Inspected the 1024, 128, 32, and 16px variants plus the compiled Finder/Dock representation from `AppIcon.icns`.
- Verified the complete icon asset catalog with `Scripts/verify-app-icon.sh` and confirmed the compiled private-CI icon is pixel-identical to the committed source raster.
- Built and signed the universal `arm64` and `x86_64` app and DMG.
- Apple accepted notarization submission `983c9801-8261-4cbf-a404-c0fd12aefb11`; staple validation, signatures, and Gatekeeper checks passed.
- Private GitHub Actions run `28723986453` passed and uploaded artifact `8086624800`.
- Full local tests passed with 0 failures using the documented macOS beta-runner hardened-runtime workaround.
- Updated the implementation plans and release evidence, then established `main` as the canonical GitHub default branch.
- No GitHub release, Homebrew submission, or public publication was created.
