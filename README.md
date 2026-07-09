# ryot-fork tooling (`fork-tooling` branch)

This branch is the **default branch** of this fork and deliberately contains
none of Ryot's own source code - it's an orphan branch holding only the
tooling that keeps this fork in sync with upstream and produces our one
custom image.

## Why this exists

Upstream Ryot gates "Pro" features behind a paid `SERVER_PRO_KEY`, checked by
`get_is_server_key_validated()` calling out to Unkey. Ryot's code (including
every Pro feature-flag gate) is genuinely GPLv3 - no separate Pro license, no
BSL/Elastic carve-out - so this is the RHEL/Rocky situation: a paywall
business model layered on top of copyleft code we're free to modify and run
ourselves. See `PRO_BYPASS.md` for the verification and the exact patch.

## Branch layout

- **`main`** - a pure, untouched, fast-forward-only mirror of
  `IgnisDa/ryot`'s `main`. Nothing is ever added or changed here. This is
  what makes syncing trivial and conflict-free forever: there's never
  anything to reconcile on this branch's own account.
- **`fork-tooling`** (this branch, default) - `patches/`, `baseline/`, and
  the one workflow that does everything else.

## What `.github/workflows/sync-and-build.yml` does

Runs daily (and on manual dispatch). Every run:

1. Fetches upstream and checks two things *before* touching anything:
   - **Does `patches/apply-pro-license-bypass.sh` still apply cleanly**
     against upstream's current code? (It uses a structural match via
     [comby](https://comby.dev), keyed on the function's name and return
     type, so it survives upstream reformatting/internal changes - only a
     renamed function or changed signature would break it.)
   - **Has upstream's own `.github/workflows/main.yml` or `website.yml`
     changed** since the copy saved in `baseline/`?
2. If either check fails: opens (or comments on) a GitHub issue explaining
   which one, and stops. `main` is not touched, no image is built.
3. If both pass: fast-forwards `main` to upstream, mirrors any new upstream
   tags, then builds **`ghcr.io/<owner>/ryot-full`** - the only image this
   fork produces - from a worktree with the patch applied fresh at build
   time. No `ryot`/`ryot-pro`-named images, no Docker Hub.

## Why upstream's own `Main`/`Website` workflows are disabled

They're copied onto `main` unmodified (since `main` is a pure mirror) but are
turned off in this fork's Actions settings, because pushing to `main` would
otherwise trigger them using upstream's original, unpatched pipeline - which
would fail anyway (no `DOCKER_TOKEN`/Docker Hub access in this fork, and the
unpatched code needs a real `UNKEY_ROOT_KEY`). `sync-and-build.yml` is the
only workflow that actually needs to run here.

## Scope note

This fork intentionally only reproduces the Docker image build. Upstream's
tag-triggered kodi-plugin/browser-extension/docs-deploy jobs are not
replicated here, since nothing in this project uses them - just the media
tracker itself. If that ever changes, `baseline/main.yml` documents exactly
what upstream's full pipeline does.

## Manual maintenance

If a sync run opens an issue:

- **Patch broken**: re-check `patches/apply-pro-license-bypass.sh`'s comby
  template against the new `get_is_server_key_validated()` signature, verify
  it (see `PRO_BYPASS.md`), commit the fix to this branch.
- **Upstream workflow changed**: read the diff, decide whether
  `sync-and-build.yml` still holds (Dockerfile path, build steps, secrets),
  update it if needed, then copy the new upstream file(s) into `baseline/` to
  clear the check.

Re-run the workflow manually (`workflow_dispatch`) once fixed.
