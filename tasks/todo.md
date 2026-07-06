# Popover Aura + Allowance Bars (2026-07-05) — DONE

Goal: premium, restrained glowing aura around the menu-bar popover matching the app icon palette (azure blue, warm gold, soft green), plus redesigned allowance bars.

Technique: NSPopover windows are a hard clipping boundary, so the aura renders inside the popover content as a masked, slowly rotating angular gradient (halo, mid diffusion, and edge filament layers). Native popover behavior untouched. On macOS 26 the edge shape uses ConcentricRectangle to match the Liquid Glass corners; older systems fall back to a rounded rectangle.

- [x] Replace AgenticGlowBorder with PopoverAura in SessionListView.swift -> verified: build succeeds
- [x] Gate motion on PopoverState.isPresented and Reduce Motion -> verified: 0.0% CPU with popover closed, ~7% open
- [x] Screenshot real popover in dark and light -> verified: aura visible, diffused, palette matches icon
- [x] Iterate: v1 too faint, v2 flooded content, v3 restrained edge light (approved direction)
- [x] Speed up motion after John could not perceive it: 28s drift, 4s breath at 55-100% -> verified: pixel diff shows 13% change over 4s, calm at any instant
- [x] Allowance bars: 4pt capsules, gradient + glow, Claude in Claude Code orange, Codex azure -> John picked style C from A/B/C/D variants
- [x] Uncolor percentage text; bars alone carry provider color
- [x] Tests green (25/25 app tests, core tests, UI tests skipped like CI)
- [x] Commit, push, confirm CI
