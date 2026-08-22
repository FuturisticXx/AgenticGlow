# AgenticGlow Strategy Decision

Date: 2026-08-21
Status: decision from an adversarial review of `docs/work-awareness/AGENTICGLOW-EVOLUTION-REVIEW.md`
Scope: product direction only. No code was changed.

Evidence labels: **Observed**, **Documented**, **Inferred**, **Proposed**.

---

## 1. Original Thesis

AgenticGlow should stay a calm, private, local macOS glancer.

It should evolve into a **provider-neutral awareness and attention layer**: better ranking, better notifications, honest state. It should not become a control plane, agent manager, or execution surface.

Shorthand from the first review:

> Trustworthy native glance, not more agents and not remote control.

The first review already named work identity and decision-shaped allowance as high-value work. It still packaged 2.0 as an attention-intelligence layer.

---

## 2. Strongest Arguments Against It

1. **Glance is being absorbed in-product.** Claude Agent View (2026-05-11) and Cursor Agents Window (2026-04-02) already glance, list, and resolve inside the harness. **Documented.**
2. **The growing category is hybrid, not awareness.** AgentBar, Rocky, DevIsland, NotchBar, Agent Deck, and official Claude remote control all close the loop. Pure awareness is table stakes. **Documented.**
3. **Detection without a last inch feels unfinished.** The current verb is “activate a nearby app.” Notification clicks miss the session. **Observed.**
4. **Tonight’s gap is work, not ranking.** Four Cursor models in one repo, Claude weekly at 1%, duplicate Claude+Cursor id. `workingDirectory` is on disk and dropped before the UI. **Observed.**
5. **“Not remote control” was used as a ban on almost all actions.** Jump, reveal, and copy are not remote control. Refusing them is how a loved glancer stays incomplete. **Inferred.**
6. **Provider-neutral display creates false equivalence.** Cursor cannot report permission or usage and still looks like a third peer. **Observed.**
7. **Attention intelligence misnames unused structure.** The significant facts already exist. They are not shown. **Observed.**

---

## 3. Evidence That Survived

- A control plane is still the wrong product. Cursor cannot participate. Claude hook decisions are unreliable. Codex app-server is a moving, currently unstable client surface. **Documented.**
- Broad Accessibility was already rejected. **Documented** in `tasks/todo.md`.
- Privacy, fail-open hooks, and native craft are still rare and still the reason this app is loved. **Documented** / **Observed.**
- Cross-harness overlap is still not owned by Cursor, Claude, or Codex. **Inferred.**
- Approve/deny from a third-party bar is occupied and unsafe. AgentBar traction is still tiny (5 stars). **Documented.**
- Menu-bar-first is still the right form. A full window, IDE extension, web app, or phone remote would compete with first parties on their home field. **Inferred.**
- Task-as-center requires prompt-like text or a new human-maintained inbox. That violates `docs/privacy.md` or becomes orchestration. **Documented.**

---

## 4. Evidence That Changed the Recommendation

- First-party harness dashboards are not “adjacent.” They are the default intra-harness future. **Documented.**
- Official Claude remote control is already the walk-away product. **Documented.**
- Codex `thread/resume` and `turn/interrupt` exist, so “we cannot act” is no longer a technical fact. It is a product choice. **Documented.**
- Live data after the first review still shows work and constraint as the missing sentence, not a missing attention score. **Observed.**
- DevIsland already claims folder/path overlap. That “unique gap” is not unique if AgenticGlow waits. **Documented.**
- The six-layer harness/provider/model/project/task/session model is right for adapters and wrong for the UI. **Inferred.**

---

## 5. Competing Product Futures

| Future | One line | Verdict |
| --- | --- | --- |
| A. Native attention layer | Smarter glance, same objects | Too thin. Absorbable. |
| B. Agent control plane | Approvals, replies, routing, dispatch | High demand, wrong identity, weak reliability. |
| C. Project intelligence layer | Projects, branches, builds, agents | Right object, easy to become a tiny IDE. |
| D. Hybrid | Work-centered awareness + last-inch actions + honest constraints | **Recommended.** |
| E. Task orchestrator | Persistent tasks across providers | Rejected. Privacy and orchestration trap. |

---

## 6. Recommended Product Boundary

**In:**

- Work grouping from `workingDirectory`
- Attention as a sort key, not the product name
- Honest capability holes
- Model on the compact row
- Constraint / continuation sentences
- Failed notification
- Duplicate-hook collapse
- Jump, reveal in Finder, copy work context, hide, refresh

**Out:**

- Approve / deny / auto-resume / reply with prompt text
- Start, queue, route, or transfer sessions
- Transcripts, token charts, cost dashboards
- Notch / island chrome
- Mobile or web remote
- Fake Cursor permission or usage
- Task graph, git/build/test product, Agents Window clone

**Gray, later only:**

- Codex `turn/interrupt` aimed at the exact thread
- Git branch if cheap, local, and honest
- History / away digest after work identity exists

---

## 7. Revised AgenticGlow Product Thesis

**AgenticGlow remains the calm, private, local awareness layer for AI coding work on a Mac.**

It is not an attention-intelligence product. It is a **cross-harness work glance** with a few reliable last-inch actions.

The sentence it must make obvious:

> This folder has these models in it. This constraint changes what you can continue. Nothing needs you unless a harness can actually say so. Click once to return to that work.

It still does not inspect prompts. It still does not drive the agent. It still does not pretend a provider can do what it cannot.

---

## 8. What AgenticGlow Is Missing

Two root causes, plus one secondary.

1. **It watches sessions. Daily work is a folder of overlapping models.**
   `workingDirectory` is collected and dropped. **Observed.**
2. **It can detect a problem and cannot finish the cheap next inch.**
   The only verb is generic activate, except Codex window raise. **Observed.**
3. **Secondary: it presents unequal systems as equal rows.**
   Cursor cannot need you and cannot show usage. **Documented.**

Attention scoring would not fix those. A control plane would over-fix them and break the product.

---

## 9. What We Should Build Next

Phase 1, against data already in hand:

1. Put `workingDirectory` on `SessionSnapshot` and group overlap.
2. Show model on the compact row; say “model unknown” when absent.
3. Let the summary state more than one true thing.
4. One continuation line under allowance when a window is low or exhausted.
5. Notify once on `.failed`.
6. Collapse or explain duplicate Claude+Cursor ids.
7. Disclose Cursor’s missing permission and usage in the UI.
8. Raise last-inch actions to the same phase: better jump where reliable, Reveal in Finder, copy work context (no prompts).

Acceptance: on a night like this one, the popover should make “four models in AgenticGlow, Claude weekly gone, Codex still has room” obvious in under two seconds.

---

## 10. What We Should Explicitly Not Build

- Permission approve/deny, including “allow for N minutes”
- Peek-and-reply or any prompt/question display
- Auto-resume, start-agent, provider switch, task queue, automated handoff
- Dynamic Island / notch control tower
- Transcript, token, or cost dashboards
- Cursor usage scraping
- Mobile or web companion
- Xcode or Cursor extensions as a primary surface
- Persistent task objects
- Git/build/test as a second product

---

## 11. Confidence Level

**Medium-high** on the boundary (awareness + last-inch, not control).

**High** that work identity is the unused center. The data is on disk tonight.

**Medium** that first-party absorption will stay incomplete for 12-24 months. Claude and Cursor are moving fast. Codex is not, yet.

**Low** on whether this user will stay multi-harness. If the daily life becomes Cursor-only, AgenticGlow’s remaining job shrinks to usage comparison and honest holes.

---

## 12. Remaining Unknowns

1. Will Cursor ship permission hooks or a local usage API? Until then, disclose, do not fake.
2. Will Anthropic ship a supported usage API and kill the cookie path?
3. Do Xcode 26.3 Claude/Codex sessions fire existing hooks?
4. How often are Claude+Cursor duplicate ids real parallelism versus third-party skill leakage? Seen twice today. Rate unknown.
5. When Claude weekly is at 1% and Cursor Grok is already in the repo, is the desired move “keep going in Cursor” or “stop”? Do not guess in copy.
6. If the owner standardizes on one harness, is a cross-harness glance still a daily product?
7. Would a single last-inch verb besides jump ever pass the bounce test without becoming remote control?

---

## Decision

**SURVIVED WITH IMPORTANT MODIFICATIONS**

Keep the original refusal to become a control plane.

Change the center from attention to work.

Admit last-inch resolution as part of the identity, not a leak in it.
