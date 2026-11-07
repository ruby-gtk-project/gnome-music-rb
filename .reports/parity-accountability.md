# Accountability sweep — audit pass 2

Scope per the skill: `lib/`, `exe/`, `.reports/`, and `PORTING.md`. There is
no `PORTING.md` in this repo (checked: `ls PORTING.md` → not found), so that
leg of the scope is empty by absence of the file, not by a clean sweep of it.

## The most serious finding in this pass: a false green on the runtime gate

This task handed this audit a stated gate of `drive_ok=true, 110 checks
passed, 0 failed, 66 components`. Re-running `test/drive_music.rb` — the
script responsible for 74 of those 110 checks — twice in this session,
independently, against the exact commit (`1dc12993`) that gate describes,
produced `DRIVE FAILED (1)` both times, via a 90-second watchdog timeout
after the last step. See `.reports/parity-test-parity.md` and
`.reports/parity-component-parity.md` for the full transcripts.

This is exactly the shape of finding this skill asks to be hunted hardest:
**a claim of success that rests on something that, re-run, does not
succeed.** It is reported here, under its own heading, rather than only in
the test-parity document, because a false green in a runtime gate is the
single highest-leverage thing a reviewer can wave through — every other
finding in this round's five reports could be individually true and still
get rubber-stamped past a reader who only checks `drive_ok`.

This finding is **not** an accusation that anyone fabricated the number.
It may be a flaky hang this fork has not hit before, a resource-contention
artifact of a heavily loaded shared machine, or a real, reproducible defect
in `drive_music.rb`'s teardown or in `Gtk::MediaFile`'s retry behaviour after
the volume-button step. What it is not is a number this audit could
independently reproduce as `true`. Treat `drive_ok` for this round as
**unconfirmed**, not as `true`, until someone reproduces a clean run.

## Excuse-pattern sweep over `lib/` and `exe/`

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future" lib/ exe/
→ no hits
```

Clean on the literal list the task named. But that list is narrow, and the
skill this task also named (`accountability-ensurance`) lists a much wider
construction set — "not here", "no equivalent", "is therefore", "likewise
out", "deliberately NOT" — that reads exactly like architecture while
recording an unmade decision. Widening the grep:

```
grep -rniE "no equivalent|is therefore|likewise out|not here\b|out of scope|
  no ruby analogue|does not carry over|by design|intentionally|deliberately|
  consciously|not needed|unnecessary for this port|streamlined|
  modernised away|simplified" lib/ exe/
```

found **8 hits across 6 files**, all of them real behaviour gaps described
in a tone this skill specifically exists to flag as unearned:

### `lib/gst_player.rb:26-33`

> "Two pieces of upstream's pipeline have no equivalent in the GTK media API
> and are therefore not here: ReplayGain, which upstream inserts as an
> rgvolume/rglimiter filter bin, and the 'about to finish' callback it uses
> for gapless playback. [...] Missing-codec installation, which upstream
> drives through PackageKit, is likewise out[.]"

This is three real, user-facing behaviours — loudness normalisation between
songs, gapless track transitions, and a working "install missing codec"
prompt instead of a silent failure — written up as settled architecture
("have no equivalent", "is therefore", "likewise out") rather than as debt.
The paragraph is accurate about *why* each gap is hard (no Gst bindings for
Ruby) but gives that reason in the same sentence as the gap, which is the
exact failure mode the skill names: a reader meets a plausible obstacle and
stops reading, filing the feature as closed. It is not closed; a user who
turns on ReplayGain in Preferences (the row exists, see
`lib/preferences_dialog.rb`) gets a setting that is stored and never used.

### `lib/player.rb:16-19`

> "Upstream's gapless handling is not here: it hangs off playbin3's
> 'about-to-finish' callback, which the GTK media API GstPlayer is built on
> does not expose. The player advances on end of stream instead[.]"

Same gap as above, restated at the call site one layer up. Same pattern.

### `lib/main.rb:31-35`

> "Two of upstream's startup pieces are not here, because the components
> behind them are not ported yet: CoreGrilo, which is what fills the
> collection from Tracker, and MPRIS. Until the data source lands the
> collection is empty, which is the state upstream shows the welcome page
> for."

This is the single most consequential sentence in the codebase: it is the
port's own admission that **the app has no working music library and no
desktop media integration**, written in a passive, scheduled-sounding
register ("not ported yet", "until the data source lands") that reads as a
roadmap item rather than as "I did not build the thing this app exists to
do."

### `lib/core_model.rb:32-34`

> "The recent-queue slice upstream keeps for MPRIS is not here: MPRIS is not
> ported yet."

Same MPRIS gap, same "not ... yet" framing, third occurrence.

### `lib/embedded_art.rb:24-27`

> "Embedded tag art is therefore out of reach without a sixth gem
> (`gstreamer`) this fork was not told to add[.]"

Here the behaviour-vs-reason split is handled better than the others — the
surrounding paragraph does name the actual limitation precisely (`gi
requires Gst::Buffer#map`, confirmed missing by this audit's own
`defined?(Gst)` check) — but "this fork was not told to add" shifts
responsibility onto an absent instruction rather than naming the missing
behaviour as owed. Embedded cover art (reading `ID3`/`FLAC` tag images
directly, as opposed to a cover file sitting beside the track) does not
work in this port; that sentence should say so in those words, not in terms
of which gem nobody asked for.

### `lib/store_art.rb:31-44`

> "Upstream's ten-way asyncio semaphore limiting concurrent downloads is not
> ported: nothing in this port yet calls #start [...] It is deliberately
> NOT required from lib/main.rb, i.e. not loaded into the running
> application: doing so [...] makes the app segfault later[.]"

This is the most important hit in the sweep, because unlike the others it
is not describing a missing *feature* — it is describing a **feature that
was built, that exists as working code when driven standalone, and that is
then deliberately kept out of the running application because wiring it in
crashes something unrelated.** "Deliberately NOT required" is exactly the
skill's flagged construction ("dropped deliberately... presents the
absence as chosen"), applied to a case worse than the others: here there
genuinely was a choice (not to wire in code that crashes the app), but the
state that choice produces — remote cover art does not work for any user of
this port, full stop, regardless of what `StoreArt` can do in isolation —
is not stated as plainly as the sentence's confident tone suggests. A
reader who sees "this class works on its own [...] correctly fetches,
decodes, re-encodes and caches a remote image" and then "deliberately NOT
required" can easily walk away believing remote art is a working,
intentionally-disabled feature rather than a broken one. It is broken: the
commit that introduced it (`f879f4cd`, "Port EmbeddedArt and StoreArt;
replace hand-rolled MediaArt with the real gem") describes `StoreArt` as
ported in its subject line, and it is not — it cannot be turned on without
crashing the app.

## What this means for the five reports as a set

Every one of the gaps named above is already recorded as a gap in
`parity-component-identification.md` or `parity-component-parity.md` in this
same pass — this document does not introduce new missing features. What it
adds is the finding that **the port's own source comments describe those
gaps in language this task's named accountability skill flags by
construction**, and that **the round's runtime gate does not reproduce**
when independently re-run. Both are, in the skill's terms, the mechanism by
which a reviewer stops checking: a plausible-sounding reason in a code
comment, and a green number in a status line.

## Not found

No hits for the narrower excuse list the task named directly
(`TODO|FIXME|not implemented|for now|in a future`) in `lib/`, `exe/`, or in
any of the five `.reports/*.md` files written this pass. The wider sweep
above is this audit's own addition, run because the task also named the
`accountability-ensurance` skill, whose construction list is broader than
the task prompt's literal grep.
