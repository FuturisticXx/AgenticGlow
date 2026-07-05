# AgenticGlow Repository Consolidation

Status: Complete — standalone canonical repository verified 2026-07-04

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

- [x] Do not begin while an AgenticGlow coding thread, Xcode build, test process, or app process is writing repository files.
- [x] Do not delete a dirty worktree before its required backup is verified.
- [x] Do not move either historical worktree inside the canonical repository.
- [x] Do not merge archived work into the canonical branch.
- [x] Do not push, publish, tag, release, notarize, or change publication gates.
- [x] Do not copy credentials, Keychain data, DerivedData, build products, or other generated artifacts into an archive commit.
- [x] Keep rollback possible until the new standalone repository passes every verification gate.

## Phase 1: Finish and freeze active AgenticGlow work

- [x] Let the active AgenticGlow implementation goal finish.
- [x] Confirm its intended changes are committed locally.
- [x] Confirm the canonical worktree is clean.
- [x] Record the canonical branch and commit:

```bash
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" status --short --branch
git -C "/Volumes/Liquid/2DaMax Development/AgenticGlow" rev-parse HEAD
```

- [x] Run the project’s complete verification ladder before migration.
- [x] Pause all Codex threads working in the repository.
- [x] Close Xcode and stop any AgenticGlow build, test, or app process.

Verify:

- Canonical Git status is clean.
- The expected branch is checked out.
- No process is modifying repository files.
- The current full test and Release-build evidence is recorded.

## Phase 2: Record repository and worktree state

- [x] Record all registered worktrees, branches, commit hashes, remotes, and tags.
- [x] Save dirty-file inventories for both historical worktrees.

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

- [x] Review every changed and untracked Task 9 source/test file.
- [x] Remove only generated AppleDouble sidecars, DerivedData, and build outputs.
- [x] Confirm the archive contains no secret, credential, cache, or user data.
- [x] Stage only meaningful source, tests, and project configuration.
- [x] Inspect the staged diff and create one archive-only commit:

```text
archive: preserve superseded task 9 work
```

- [x] Do not merge this commit into the canonical AgenticGlow branch.

Verify:

- Task 9 worktree is clean after the archive commit.
- Generated files are not committed.
- The archive commit is reachable from `codex/task-9-setup`.
- The archive commit can be restored independently if ever needed.

## Phase 4: Back up the redundant Devin work

- [x] Export a binary patch of tracked Devin changes.
- [x] Archive any untracked source files separately.
- [x] Exclude DerivedData, build products, caches, and AppleDouble files.
- [x] Record the branch, base commit, and creation date beside the backup.
- [x] Do not create a redundant product commit from this dirty rename.

Suggested backup directory:

`/Volumes/Liquid/AgenticGlow-Migration-Backup/devin-task-11/`

Verify:

- The patch is nonempty and readable.
- The untracked-source archive can be listed successfully.
- No credential material or generated build output is present.

## Phase 5: Create a complete Git bundle

- [x] Create a migration-backup directory outside all worktrees.
- [x] Create a bundle containing every branch and tag.
- [x] Verify the bundle and record its SHA-256 checksum.

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

- [x] Create a temporary sibling clone from the verified bundle or existing repository:

`/Volumes/Liquid/2DaMax Development/.AgenticGlow-migration`

- [x] Check out the canonical AgenticGlow branch.
- [x] Restore the original remote configuration. Do not leave the old local repository path as the permanent `origin`.
- [x] Confirm `.git` is a real directory, not a linked-worktree pointer file.

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

- [x] Generate the Xcode project twice and prove byte-stable output.
- [x] Run the complete test suite, including UI tests.
- [x] Run the privacy verifier.
- [x] Run the standalone-helper verifier.
- [x] Build the universal Release app.
- [x] Confirm both app and helper contain `arm64` and `x86_64`.
- [x] Run the legacy-name scan required by the current project.
- [x] Confirm Git status remains clean.

Stop the migration if the standalone clone differs from the frozen canonical repository or any gate fails.

## Phase 8: Perform the atomic directory swap

- [x] Reconfirm all AgenticGlow threads and processes are paused.
- [x] Rename the current linked worktree:

```text
AgenticGlow → AgenticGlow-linked-backup
```

- [x] Rename the verified standalone clone:

```text
.AgenticGlow-migration → AgenticGlow
```

- [x] Do not delete the linked backup yet.

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

- [x] Use the old repository administration directory to unregister `AgenticGlow-linked-backup` cleanly.
- [x] Unregister `AgenticGlow-task9` after confirming its archive commit and bundle backup.
- [x] Prune stale worktree registrations.
- [x] Do not use raw Finder deletion before Git unregisters linked worktrees.

Verify:

- The new standalone repository does not depend on the old shared Git directory.
- Task 9 archive commit remains recoverable from the new repository or bundle.
- Removed worktree paths no longer appear in the old worktree registry.

## Phase 10: Retire the old Devin repository

- [x] Reverify the Devin patch and untracked-source archive.
- [x] Reverify the complete Git bundle.
- [x] Confirm the standalone repository has the canonical branch and required historical refs.
- [x] Remove `AgenticGlow-devin-task-11` only after all linked worktrees have been unregistered.

Verify:

- The canonical repository continues to pass `git fsck --full`.
- The canonical repository builds and tests without the Devin directory.
- No Git pointer references the removed directory.

## Phase 11: Final cleanup

- [x] Confirm the only active visible product repository is:

`/Volumes/Liquid/2DaMax Development/AgenticGlow`

- [x] Remove obsolete generated build directories.
- [x] Update the Codex saved project to the canonical path.
- [x] Update local scripts, shortcuts, and workspace references containing retired paths.
- [x] Resume the AgenticGlow implementation thread at the canonical path.
- [x] Keep the migration bundle until John approves permanent backup removal.

## Completion gate

This task is complete only when:

- [x] AgenticGlow is one standalone repository at the canonical path.
- [x] Its `.git` directory is self-contained.
- [x] No nested worktree exists inside AgenticGlow.
- [x] No obsolete top-level AgenticGlow worktree folder remains.
- [x] Canonical branch, commit, remotes, and tags are preserved.
- [x] Task 9 work is recoverable from its archive commit.
- [x] Devin changes are recoverable from the defensive backup.
- [x] The complete Git bundle verifies successfully.
- [x] Full tests, privacy/helper checks, deterministic generation, and universal Release build pass after consolidation.
- [x] No push, merge, tag, publication, or release occurred during consolidation.

## Completion evidence

- Canonical standalone repository: `/Volumes/Liquid/2DaMax Development/AgenticGlow`
- Frozen and final product commit before this completion record: `ef84c9f2b7f0d1385d8ab12ddf5b79fe08195af3`
- Task 9 archive commit and local recovery branch: `77fe3bbc56df31c9e4f01d3b8831dafc0439a3f0` (`archive/task-9-superseded`)
- Devin base recovery branch: `768e989d0865f015ad73618b262e52f9c2a29adf` (`archive/devin-task-11-base`)
- Verified complete bundle: `/Volumes/Liquid/AgenticGlow-Migration-Backup/AgenticGlow-all.bundle`
- Bundle SHA-256: `0b3dc2e6916545b87d36ffd25d8aa16b6bd7399cdd1c7e5e5c911a1687e600ed`
- Devin tracked-change patch SHA-256: `848adb857c2b32a1d77f5974731801871c2daa588e2200bed31e115fe8fd2e2f`
- Devin untracked-source archive SHA-256: `10f60781286aee0624d68848965507be0a0bddba21a6239655aca64e0d7a01e8`
- Final full test suite: 151 tests passed with 0 failures using the documented local beta-runner workaround.
- Final project generation was byte-stable at SHA-256 `476a7ad55e7883dffbf87db9f3ab3676b082bcd3ef9ee52bc28a47ccedfbf4d3`.
- Final Release app and helper both contain `x86_64 arm64` slices.
- Privacy, standalone-helper, app-icon, and legacy-name checks passed.
- No push, merge, tag, notarization, publication, or release occurred during consolidation.
