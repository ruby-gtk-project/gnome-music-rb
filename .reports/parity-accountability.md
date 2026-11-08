# Accountability sweep — audit pass 3

Scope per the skill: `lib/`, `exe/`, `.reports/`, and `PORTING.md`. There is
still no `PORTING.md` in this repo (`ls PORTING.md` → not found, re-checked
this pass), so that leg of the scope remains empty by absence of the file.

## Good news first, because it is also an accountability question: the previous pass's headline finding is actually fixed

Pass 2's most serious finding was a false green on the runtime gate:
`drive_music.rb` failed via watchdog timeout on two independent re-runs
against the commit the gate claimed was clean. This pass re-ran it fresh
against the current HEAD (`f324a75d`) and it reproduces `DRIVE OK, 74/74`
cleanly — see `.reports/parity-test-parity.md` for the transcript. The
commit that fixed it names the real bug (a mis-used libadwaita signal) and
the fix was independently verified here, not merely re-asserted. This is
what the skill asks for done right: a gap was found, named, fixed, and the
fix was re-verified by someone other than whoever wrote it. Recorded here
because this skill's job includes noticing when something *was* built, not
only when it was not.

## This pass's own finding: a commit message overclaims what its own code admits

Commit `0c0021e7`, "Call grilo for real: resolve remote album covers
through Grl", describes landing a working call. Its own code, read in full
(`lib/core_grilo.rb:69-70`, `resolve_on`'s `rescue NotImplementedError`),
documents that the one call being made —`Grl::Source#resolve`— **always
raises**, through a GList-marshalling gap this gem's binding has, and the
rescue exists specifically to keep that from crashing the caller. The
in-code class comment is honest about this ("see the class comment for why
that currently never happens" — `lib/core_grilo.rb:67`) — the dishonesty,
such as it is, lives only in the commit subject line, which a reader
scanning `git log` (as this task's own next-round reviewer might) would
read as "cover resolution now works" rather than "cover resolution is now
attempted through a real API call that this binding cannot actually
complete." The distinction matters: "calls grilo for real" is a true
statement about the code path and a false implication about the user
-visible outcome, and a commit subject is exactly the kind of place a
future reader stops reading past. This is reported here, not as a
retraction of the commit's value (the registry setup, plugin loading and
graceful-failure handling it added are real and were not there before), but
because a subject line that oversells its own diff is the mechanism this
skill exists to catch, regardless of whether the body backs off the claim
later (`0c0021e7`'s body does state the `NotImplementedError` outcome, to
its credit — but a reader of `git log --oneline` never sees the body).

## Excuse-pattern sweep, re-run this pass over `lib/`, `exe/`, and `.reports/`

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future" lib/ exe/
→ 1 hit: lib/core_grilo.rb:31, a literal quoted gobject-introspection error
  string ("TODO: [keys] in Ruby -> ..."), not an excuse written by this
  port — it is evidence quoted to explain a real binding limitation.
  Not a finding on its own; flagged so the next pass does not re-discover
  the same line and wonder whether it was missed.
```

Widening to the skill's fuller construction list, same as pass 2:

```
grep -rniE "no equivalent|is therefore|likewise out|not here\b|out of scope|
  no ruby analogue|does not carry over|by design|intentionally|deliberately|
  consciously|not needed|unnecessary for this port|streamlined|
  modernised away|simplified|not ported yet|not yet ported" lib/ exe/
```

**16 hits across 10 files, unchanged in substance from pass 2's 8 hits
across 6 files** — the extra count is from re-including the "not ported
yet" variant and from genuinely new files (`core_grilo.rb`, `tracker_store.rb`,
`embedded_art.rb` landed since pass 2 and carry the same kind of sentence).
Every one of them restates a gap already named in
`.reports/parity-component-identification.md` or
`.reports/parity-component-parity.md` from this same pass:

- `lib/main.rb:32-35` — "Two of upstream's startup pieces are not here...
  CoreGrilo, which is what fills the collection from Tracker, and MPRIS."
  **This comment is now stale in a way worth flagging on its own**:
  `CoreGrilo` the *file* is no longer absent (it landed in `0c0021e7`) —
  what is still absent is CoreGrilo's *collection-filling* role. The
  comment conflates "the class exists" with "the class does this job",
  which is the same conflation this pass's component-identification report
  had to untangle independently. A comment that goes stale the moment a
  class lands, while the underlying behavioural gap it describes is still
  real, is a smaller version of the same risk as an overselling commit
  subject: the words say more got fixed than did.
- `lib/core_grilo.rb:19-24` — "StoreArt is deliberately not required
  anywhere live yet" — same "deliberately NOT required" framing pass 2
  flagged on `store_art.rb` itself, now also stated from the caller's side.
  Still true this pass: confirmed zero `require_relative 'store_art'`
  outside its own file/spec.
- `lib/store_art.rb:31-44`, `lib/embedded_art.rb:24-27`,
  `lib/gst_player.rb:26-33`, `lib/player.rb:16-19`, `lib/core_model.rb:32-34`
  — all re-confirmed present verbatim, same gaps pass 2 named, still
  unresolved, not re-litigated in full here since nothing about them
  changed.
- `lib/window.rb:29`, `lib/core_album.rb:13`, `lib/search_header_bar.rb:14`,
  `lib/core_artist.rb:13`, `lib/core_disc.rb:13`, `lib/tracker_store.rb:15`
  — new-to-this-pass hits, all the same pattern applied to the same
  underlying "no real Tracker collection source" gap, stated once per file
  that touches it. Six restatements of one gap is not six gaps, but it is
  worth naming as a pattern: the gap is pervasive enough that it leaves a
  comment in nearly every data-layer file, which is itself a signal of how
  central the missing piece is to the app's actual purpose.

## Not found

No hit for any construction claiming a feature is complete when this
audit's own re-running of the suites says otherwise — the opposite of pass
2's finding, where the runtime gate itself was the false claim. This pass
found no second instance of that specific failure mode (a claimed-green
check that does not reproduce); the one gate re-run this pass (`drive_music.rb`)
reproduced clean.

## What this means for the five reports as a set

Same structure as pass 2: every gap named above is already recorded in the
identification or parity report from this pass; this document's job is the
language sweep and the reproducibility check, not discovering new gaps on
its own. This pass's two additions to pass 2's method: (1) catching a
commit *subject line* overclaiming what its own commit *body* and the
resulting *code* actually admit, and (2) catching a source comment that
went stale the moment a file landed, while the behaviour it describes
stayed missing. Both are instances of the same underlying risk the skill
exists to guard against — a reader stopping at a confident-sounding
sentence instead of at the behaviour the sentence claims to describe.
