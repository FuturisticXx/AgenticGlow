# AgenticGlow Task-Aware Session Titles Design

**Date:** 2026-07-05

## Goal

Replace vague folder-only session labels such as `memories` with a concise description of the work while retaining the project folder as secondary context.

The display priority is:

1. Provider thread title.
2. Locally generated task title.
3. Project folder name.

## Approved presentation

The primary row text shows the task-aware title. The existing phase and surface detail becomes phase and project context.

Example:

```text
Automate Claude cookie setup
Working · memories
```

The project folder remains available for source activation, accessibility context, diagnostics, and fallback behavior. This feature does not replace `projectName` or `workingDirectory`.

## Title sources

### Codex

Codex stores local thread names in `~/.codex/session_index.jsonl` as records containing `id` and `thread_name`. AgenticGlow uses the raw hook `session_id` to find the matching record before hashing the identifier for persisted session state.

If a matching non-empty `thread_name` exists, it becomes the provider title. AgenticGlow does not read prompts, responses, previews, or transcript contents to obtain it.

### Claude

Claude hook input currently includes `session_id`, `transcript_path`, `cwd`, and event-specific fields, but it does not provide the current session title. `UserPromptSubmit` includes the submitted `prompt`, and Claude supports setting `sessionTitle` through hook output.

AgenticGlow does not change Claude's own session title in this version. It creates a local fallback title from the first eligible `UserPromptSubmit` prompt and uses a provider title later if Anthropic exposes one through hook input.

### Other events

Events without a new title retain the previous title for the same session. They never downgrade an existing provider or generated title to the folder name.

## Local title generation

Generation is deterministic and entirely on-device. It makes no network request and invokes no language model.

The generator:

- Uses only the first eligible user prompt for a session.
- Collapses whitespace and removes leading conversational filler.
- Selects the first meaningful sentence or clause.
- Produces at most 60 display characters.
- Removes line breaks, control characters, URLs, and obvious credential-shaped values.
- Rejects empty, command-only, or unsafe results.
- Does not update the generated title on later turns.

If generation fails, AgenticGlow uses the project folder.

## Data model

`NormalizedEvent` gains optional title metadata:

- `sessionTitle`: sanitized display title.
- `sessionTitleSource`: `provider` or `generated`.

The raw provider session identifier is used only during event normalization and is not persisted. Existing hashed `sessionID` behavior remains unchanged.

`SessionSnapshot` carries the resolved optional title. `SessionRowView` chooses `sessionTitle ?? projectName` as its primary text and includes `projectName` in the secondary line when a distinct title is present.

## Title precedence and updates

For each session:

1. A non-empty provider title replaces a generated title.
2. A generated title fills an empty title but does not replace another generated title.
3. An event without title metadata preserves the previous event's title.
4. Folder name remains the final display fallback.

Titles are scoped by provider and session ID so simultaneous sessions in the same folder remain distinguishable.

## Privacy

AgenticGlow continues to reject storage of raw prompts, responses, commands, tool arguments, and transcript content.

Only the final sanitized title may be persisted. The title is treated as session metadata, documented in `docs/privacy.md`, bounded to 60 characters, and deleted with the existing session-state lifecycle.

The implementation must never log title-generation input or include raw prompt text in errors, fixtures, caches, or diagnostics.

## Failure behavior

- Missing or malformed Codex index: generate a local title or use the folder.
- Missing Codex thread record: generate a local title or use the folder.
- Unreadable provider metadata: do not surface an error in the menu.
- Unsafe or empty generated title: use the folder.
- Older stored events without title fields: decode normally and use the folder.

Provider metadata failures must not affect session status, allowance refresh, hook delivery, or source activation.

## Verification

Tests must prove:

- Codex thread titles resolve by raw session ID.
- Unrelated Codex index records are ignored.
- Provider title outranks generated title and folder name.
- Generated titles are stable after the first prompt.
- Raw prompt text is never persisted.
- Credentials, URLs, control characters, and multiline content are removed or rejected.
- Older event files remain decodable.
- Session rows show the title as primary text and project as secondary context.
- Accessibility labels include both task title and project context without exposing prompt text.
- Existing privacy, helper, integration, full non-UI, and UI-test checks remain green.

## Out of scope

- Network or model-based title generation.
- Reading full Codex or Claude transcripts.
- Modifying Claude's provider-side session title.
- User-editable aliases.
- Title history or analytics.
