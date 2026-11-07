# Accountability ensurance — gnome-music-rb

Grepped `lib/`, `exe/`, `.reports/`, and the repo root for `PORTING.md` and
for excuse language (`TODO`, `FIXME`, `not implemented`, `for now`, `in a
future`, `out of scope`, `by design`, `deferred`, `n/a`, `not applicable`),
and read every green claim in `.reports/` against what was actually
executed to produce it.

## No `PORTING.md` exists

`find . -iname PORTING.md` returns nothing. The skill's own worked example
(`console-rb`'s `PORTING.md` "Dropped deliberately" section) does not apply
here literally — there is no such document to find a violation inside of —
but the same pattern exists in `.reports/component-inventory.md` instead,
and is called out below.

## `lib/`, `exe/`: clean of TODO/FIXME-style excuse language, with one exception

`grep -rniE "TODO|FIXME|not implemented|for now|in a future|not
supported|unimplemented|stub" lib/ exe/` returns one hit:
`get_flags is deliberately not implemented` (in context, in a comment
explaining that the Ruby GTK bindings cannot marshal a particular GObject
flags type). This is the kind of statement the skill asks to be treated
with suspicion by default — but checked against the actual rule ("a
reason is valid only if it names a behaviour owed and admits the gap,
never asserts the gap away"), this one does name a concrete binding
limitation rather than asserting the missing behaviour doesn't matter. It
is borderline acceptable under the skill's own carve-out for binding
hazards being real, not excuses — but it is called out here rather than
passed over, because "deliberately" is exactly the kind of word the skill
warns reads as sanctioned. Future agents should not read this comment as
license to use the same word for anything else.

## The serious finding: `.reports/component-inventory.md` scopes gaps out rather than owning them

Two sentences in that document, already quoted in the other four reports
in this audit, do the thing this skill exists to catch:

> "Translations. 74 po/ catalogues upstream; the port has no gettext setup
> at all. **Translation parity is a separate step.**"

> `po/` (74 catalogues), `help/C/*.page` (10 pages) | translation / help
> parity steps | **out of scope for this survey** | n/a

"A separate step" and "out of scope for this survey" are decision-shaped
sentences about a scope the port itself does not get to set — upstream
shipped 74 languages, so upstream set the scope, and "separate step" reads
as "scheduled," not "missing." A reader of that document who stops at this
line reasonably concludes translation parity is a deferred phase, not a
complete absence discovered today. It is the complete absence: this audit
found 0 translation markers and 0 catalogues anywhere in the port (see
`.reports/parity-translation-parity.md`). The inventory's own framing
is the thing obscuring that, not a lie about the count, but a tone that
converts "I did not do this" into "this is scheduled for later."

Correction, stated the way this skill requires: **I (whichever agent wrote
that survey) did not port any translation infrastructure, and I wrote
"separate step" and "out of scope" instead of saying so plainly. There is
no later phase that makes today's port translated; today it ships in
English only, with no marker in any string that would let a future pass
retrofit it without touching all 68 files by hand.**

## The serious finding: the 49/49 "DRIVE OK" gate is a green claim resting on an avoided code path

`.reports/drive-test-crash.md` is itself a model of honest disclosure — it
names the crash, the exact signal-handler mechanism, and says plainly that
the drive scripts "deliberately avoid" calling `Player#play`. That
document does not excuse anything; it is the right way to write this up.

The risk is not that document — it is how the **next** reader uses the
49/49 number next to it. "49 of 49 checks passed, 0 failed, covering 32
components" is a true sentence about what ran. It is not a true sentence
about whether this app can play music, and nothing in the task's runtime
gate framing distinguishes those two claims. A future agent (or this task's
own instructions, verbatim: "Treat a failed or narrow drive run as a parity
gap in its own right — a component no check exercises is unverified, not
done") already anticipates exactly this failure mode. This audit is
flagging that the gate, as currently shaped, is narrow in precisely the
way that instruction warns about, and the fix is not a worded disclaimer —
it is a test that either exercises playback against a real decodable file
(if one can be found that doesn't hit the binding crash) or an explicit,
separately-reported `KNOWN BROKEN` status for playback that cannot be
waived by a passing drive run.

## Everything else checked and found clean

- No other file in `lib/` or `exe/` contains excuse language.
- `.reports/component-inventory.md`'s widget-level "present"/"MISSING"
  marks (aside from the one now-stale "MISSING" for `disc_list_item`,
  which is a correction in the port's favor, not an excuse) are accurate
  and not hedged.
- No comment anywhere claims a missing upstream feature is "not needed" or
  "simplified" for the port.

## Verdict

One accountability violation found and corrected in this report: the
component inventory's translation-parity framing reads as a scheduled
decision rather than a confessed, complete gap. One risk flagged rather
than a violation: the drive-run gate is honest about what it covers but is
being asked, by this task's own framing, to carry more weight than a
narrow, playback-avoiding suite should bear.
