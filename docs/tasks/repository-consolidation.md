# AgenticGlow Repository Consolidation

Status: In progress — canonical repository frozen for consolidation

## Goal

Consolidate AgenticGlow into one clean, standalone repository at:

`/Volumes/Liquid/2DaMax Development/AgenticGlow`

Preserve recoverable historical work, remove obsolete visible worktrees, and avoid disrupting active development.

## Current layout

- Canonical product worktree: `/Volumes/Liquid/2DaMax Development/AgenticGlow`
- Shared Git database and old Devin worktree: `/Volumes/Liquid/2DaMax Development/AgenticGlow-devin-task-11`
- Superseded Task 9 worktree: `/Volumes/Liquid/2DaMax Development/AgenticGlow-task9`

The canonical product directory is currently a linked Git worktree. Its `.git` file points into the shared Git database stored under `AgenticGlow-devin-task-11`. Therefore, `AgenticGlow-devin-task-11` must not be deleted until a verified standalone repository has replaced the linked worktree.

Neither historical worktree should be moved inside the canonical AgenticGlow directory. Nested repositories and worktrees can pollute Git status, searches, builds, and Xcode project discovery.

## Known preservation decisions

### Devin Task 11

- The branch is behind the canonical AgenticGlow branch.
- Its meaningful dirty file contents are already reachable from repository history.
- Do not merge or commit its redundant dirty rename.
- Export a defensive patch before removal.

### Task 9

- The branch is behind the canonical AgenticGlow branch.
- It contains unique uncommitted source and test blobs from an older implementation.
- The work includes superseded approaches, including a framework-dependent helper design that the current standalone-helper architecture replaced.
- Do not merge these changes into current AgenticGlow.
- Preserve meaningful source and tests in one clearly labeled archive commit before removing the worktree.

## Hard constraints

- [ ] Do not begin while an AgenticGlow coding thread, Xcode build, test process, or app process is writing repository files.
- [ ] Do not delete a dirty worktree before its required backup is verified.
- [ ] Do not move either historical worktree inside the canonical repository.
- [ ] Do not merge archived work into the canonical branch.
- [ ] Do not push, publish, tag, release, notarize, or change publication gates.
- [ ] Do not copy credentials, Keychain data, DerivedData, build products, or other generated artifacts into an archive commit.
- [ ] Keep rollback possible until the new standalone repository passes every verification gate.

## Phase 1: Finish and freeze active AgenticGlow work

- [ ] Let the active AgenticGlow implementation goal finish.
- [ ] Confirm its intended changes are committed locally.
- [ ] Confirm the canonical worktree is clean.
- [ ] Record the canonical branch and commit:

```bash
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" status --short --branch
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" rev-parse HEAD
```

- [ ] Run the project’s complete verification ladder before migration.
- [ ] Pause all Codex threads working in the repository.
- [ ] Close Xcode and stop any AgenticGlow build, test, or app process.

Verify:

- Canonical Git status is clean.
- The expected branch is checked out.
- No process is modifying repository files.
- The current full test and Release-build evidence is recorded.

## Phase 2: Record repository and worktree state

- [ ] Record all registered worktrees, branches, commit hashes, remotes, and tags.
- [ ] Save dirty-file inventories for both historical worktrees.

```bash
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" worktree list --porcelain
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" branch -vv --no-abbrev
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" remote -v
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" tag --list
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow-devin-task-11" status --short
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow-task9" status --short
```

Verify:

- Every branch and worktree has an identified owner and purpose.
- The canonical commit recorded in Phase 1 has not changed.

## Phase 3: Archive meaningful Task 9 work

- [ ] Review every changed and untracked Task 9 source/test file.
- [ ] Remove only generated AppleDouble sidecars, DerivedData, and build outputs.
- [ ] Confirm the archive contains no secret, credential, cache, or user data.
- [ ] Stage only meaningful source, tests, and project configuration.
- [ ] Inspect the staged diff and create one archive-only commit:

```text
archive: preserve superseded task 9 work
```

- [ ] Do not merge this commit into the canonical AgenticGlow branch.

Verify:

- Task 9 worktree is clean after the archive commit.
- Generated files are not committed.
- The archive commit is reachable from `codex/task-9-setup`.
- The archive commit can be restored independently if ever needed.

## Phase 4: Back up the redundant Devin work

- [ ] Export a binary patch of tracked Devin changes.
- [ ] Archive any untracked source files separately.
- [ ] Exclude DerivedData, build products, caches, and AppleDouble files.
- [ ] Record the branch, base commit, and creation date beside the backup.
- [ ] Do not create a redundant product commit from this dirty rename.

Suggested backup directory:

`/Volumes/Liquid/AgenticGlow-Migration-Backup/devin-task-11/`

Verify:

- The patch is nonempty and readable.
- The untracked-source archive can be listed successfully.
- No credential material or generated build output is present.

## Phase 5: Create a complete Git bundle

- [ ] Create a migration-backup directory outside all worktrees.
- [ ] Create a bundle containing every branch and tag.
- [ ] Verify the bundle and record its SHA-256 checksum.

Suggested artifact:

`/Volumes/Liquid/AgenticGlow-Migration-Backup/AgenticGlow-all.bundle`

```bash
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" bundle create \
  "/Volumes/Liquid/AgenticGlow-Migration-Backup/AgenticGlow-all.bundle" \
  --all

git bundle verify \
  "/Volumes/Liquid/AgenticGlow-Migration-Backup/AgenticGlow-all.bundle"

shasum -a 256 \
  "/Volumes/Liquid/AgenticGlow-Migration-Backup/AgenticGlow-all.bundle"
```

Verify:

- Bundle verification succeeds.
- Canonical, Task 9 archive, Devin, and other required refs are included.

## Phase 6: Build a standalone replacement repository

- [ ] Create a temporary sibling clone from the verified bundle or existing repository:

`/Volumes/Liquid/2DaMax Development/.AgenticGlow-migration`

- [ ] Check out the canonical AgenticGlow branch.
- [ ] Restore the original remote configuration. Do not leave the old local repository path as the permanent `origin`.
- [ ] Confirm `.git` is a real directory, not a linked-worktree pointer file.

Verify:

```bash
git -C "/Volumes/Liquid/2DaMax Development/.AgenticGlow-migration" fsck --full
git -C "/Volumes/Liquid/2DaMax Development/.AgenticGlow-migration" status --short --branch
git -C "/Volumes/Liquid/2DaMax Development/.AgenticGlow-migration" rev-parse HEAD
git -C "/Volumes/Liquid/2DaMax Development/.AgenticGlow-migration" remote -v
```

- `git fsck --full` succeeds.
- The commit matches the frozen canonical commit from Phase 1.
- The working tree is clean.
- Required historical refs remain recoverable.
- Remote URLs match the original repository.

## Phase 7: Verify the standalone clone

Run the full project verification ladder in `.AgenticGlow-migration`:

- [ ] Generate the Xcode project twice and prove byte-stable output.
- [ ] Run the complete test suite, including UI tests.
- [ ] Run the privacy verifier.
- [ ] Run the standalone-helper verifier.
- [ ] Build the universal Release app.
- [ ] Confirm both app and helper contain `arm64` and `x86_64`.
- [ ] Run the legacy-name scan required by the current project.
- [ ] Confirm Git status remains clean.

Stop the migration if the standalone clone differs from the frozen canonical repository or any gate fails.

## Phase 8: Perform the atomic directory swap

- [ ] Reconfirm all AgenticGlow threads and processes are paused.
- [ ] Rename the current linked worktree:

```text
AgenticGlow → AgenticGlow-linked-backup
```

- [ ] Rename the verified standalone clone:

```text
.AgenticGlow-migration → AgenticGlow
```

- [ ] Do not delete the linked backup yet.

Verify:

- Canonical path is `/Volumes/Liquid/2DaMax Development/AgenticGlow`.
- Canonical `.git` is self-contained.
- Branch and commit match Phase 1.
- Git status is clean.
- Remotes are correct.
- Xcode opens the expected project.
- A fresh build and targeted smoke test pass from the final path.

Rollback:

If verification fails, rename the new directory back to `.AgenticGlow-migration` and restore `AgenticGlow-linked-backup` to `AgenticGlow`.

## Phase 9: Remove obsolete registered worktrees

Only proceed after the standalone repository passes Phase 8.

- [ ] Use the old repository administration directory to unregister `AgenticGlow-linked-backup` cleanly.
- [ ] Unregister `AgenticGlow-task9` after confirming its archive commit and bundle backup.
- [ ] Prune stale worktree registrations.
- [ ] Do not use raw Finder deletion before Git unregisters linked worktrees.

Verify:

- The new standalone repository does not depend on the old shared Git directory.
- Task 9 archive commit remains recoverable from the new repository or bundle.
- Removed worktree paths no longer appear in the old worktree registry.

## Phase 10: Retire the old Devin repository

- [ ] Reverify the Devin patch and untracked-source archive.
- [ ] Reverify the complete Git bundle.
- [ ] Confirm the standalone repository has the canonical branch and required historical refs.
- [ ] Remove `AgenticGlow-devin-task-11` only after all linked worktrees have been unregistered.

Verify:

- The canonical repository continues to pass `git fsck --full`.
- The canonical repository builds and tests without the Devin directory.
- No Git pointer references the removed directory.

## Phase 11: Final cleanup

- [ ] Confirm the only active visible product repository is:

`/Volumes/Liquid/2DaMax Development/AgenticGlow`

- [ ] Remove obsolete generated build directories.
- [ ] Update the Codex saved project to the canonical path.
- [ ] Update local scripts, shortcuts, and workspace references containing retired paths.
- [ ] Resume the AgenticGlow implementation thread at the canonical path.
- [ ] Keep the migration bundle until John approves permanent backup removal.

## Completion gate

This task is complete only when:

- [ ] AgenticGlow is one standalone repository at the canonical path.
- [ ] Its `.git` directory is self-contained.
- [ ] No nested worktree exists inside AgenticGlow.
- [ ] No obsolete top-level AgenticGlow worktree folder remains.
- [ ] Canonical branch, commit, remotes, and tags are preserved.
- [ ] Task 9 work is recoverable from its archive commit.
- [ ] Devin changes are recoverable from the defensive backup.
- [ ] The complete Git bundle verifies successfully.
- [ ] Full tests, privacy/helper checks, deterministic generation, and universal Release build pass after consolidation.
- [ ] No push, merge, tag, publication, or release occurred during consolidation.
