# Pro license-check bypass: what and why

## Verified before touching anything

- Cloned the real repo and read the code directly, rather than trusting
  Ryot's own marketing framing of "Pro."
- The entire repo, including every Pro feature-flag gate, ships under the
  single repo-root **GPLv3** - verbatim FSF text, no BSL/Elastic/FSL
  carve-out, no separate LICENSE-PRO, no per-file license headers anywhere.
- "Pro" is not a separately-licensed body of code; it's a boolean consumed by
  `if` guards scattered across the codebase (e.g.
  `crates/utils/dependent/collection/src/lib.rs`,
  `crates/services/fitness/src/template_management.rs`,
  `crates/services/user/src/access_link_operations.rs`), but every one of
  those guards reads from a single source of truth:
  `get_is_server_key_validated()` in
  `crates/utils/dependent/core/src/lib.rs`.

This is the RHEL/Rocky situation: genuinely copyleft code plus a business
model built on a paywall mechanism, not a license term restricting use.
Business model and license model are orthogonal - modifying and running our
own build privately triggers no GPLv3 disclosure obligation at all (that
only activates if the modified binary is *distributed* to someone else,
which a personal self-hosted instance isn't).

## The one edge

`get_is_server_key_validated()` is the only place that reaches out over the
network - it POSTs `server.pro_key` to Unkey's
`api.unkey.com/v2/keys.verifyKey` and caches the result. Every scattered
`if`-guard elsewhere just calls *this* function and trusts its answer. So the
fix is exactly one change at exactly that edge: make it unconditionally
return `true` (skip the Unkey call entirely) - every downstream guard then
sees Pro as active, with zero changes anywhere else in the codebase.

Deliberately **not** patched as part of this: the unused imports this leaves
behind in the same file (`nest_struct`, `HeaderValue`, `AUTHORIZATION`,
`Date`, `convert_naive_to_utc`, `get_base_http_client`, `UNKEY_ROOT_KEY`,
`Serialize`/`Deserialize`, and the `ss` parameter itself). Removing them
would shrink the diff cosmetically but adds risk for no real benefit: if
upstream ever reuses one of those imports for something else in this file,
a diff-based patch touching those lines would conflict; comby's structural
match doesn't touch them at all, so there's nothing to conflict. They just
produce harmless `unused_imports`/`unused_variables` *warnings* (verified:
no `deny(warnings)` anywhere in this codebase, so this never fails a build).

## Why comby instead of a plain diff/patch file

A line-based patch (`git diff` / `git apply`) requires near-exact context
around the change - if upstream so much as reformats a nearby log message
inside this function, the patch stops applying and needs manual
re-generation. [comby](https://comby.dev)'s structural match instead keys
only on the function's **name and return type**:

```
async fn get_is_server_key_validated(:[params]) -> Result<bool> {
    :[body]
}
```

Anything upstream changes *inside* that function's body keeps matching and
getting replaced with `Ok(true)` - the patch only breaks if upstream renames
the function or changes its signature, which is exactly the case where a
human should be looking at it anyway (that's what the sync workflow's first
safety check catches).

## Verification performed

- Compiled the patched crate in isolation (`cargo check -p
  dependent-core-utils`) with placeholder `APP_VERSION`/`UNKEY_ROOT_KEY`
  values - **zero errors**, only the expected unused-import/-variable
  warnings described above.
- Ran the comby rewrite twice in a row against the same file to confirm it's
  idempotent (a no-op the second time, not an error) - matters because the
  sync workflow always applies fresh to a clean `main` checkout, but manual
  re-runs should behave sanely too.
- Confirmed `UNKEY_ROOT_KEY` has exactly one runtime use in the entire repo
  (the line this patch removes) and one compile-time-only declaration
  (`crates/utils/env/src/lib.rs`, via Rust's `env!()` macro, which only
  requires the variable be *present* at compile time - any placeholder
  string satisfies it, since the value is never read anywhere after this
  patch).

## Files

- `patches/apply-pro-license-bypass.sh` - the actual patcher (comby via
  Docker), idempotent, fails loudly (non-zero exit, no silent partial state)
  if the function signature no longer matches.
