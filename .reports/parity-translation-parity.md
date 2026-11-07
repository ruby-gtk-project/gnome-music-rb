# Translation parity — audit pass 2

| | |
|---|---|
| Upstream | `master` @ `63527674` |
| Port | `ruby` @ `1dc12993` |
| Domain | `gnome-music` (upstream's; not configured anywhere in the port, since there is no gettext setup to configure) |
| Upstream languages | 74 `.po` files (`po/LINGUAS`, 74 codes, re-verified this pass: `git ls-tree -r --name-only origin/master \| grep '^po/.*\.po$' \| wc -l` → 74) |
| Upstream POTFILES | 45 files marked for extraction (`po/POTFILES.in`) |
| Port messages marked for translation | **0** |
| Port languages shipped | **0 / 74** |

## Re-verified this pass: still total absence

```
$ find . -iname '*.po' -o -iname '*.pot'        (repo root, excluding .git)
(no output)
$ grep -rn "gettext\|FastGettext\|_(\"" lib/ exe/
(no output)
```

No `.po`, `.pot`, or `.mo` anywhere in the repository. No gettext gem
(`gettext`, `fast_gettext`, `r18n`, anything) is required anywhere in `lib/`
or in the `Gemfile`/gemspec. Every user-visible string checked in this pass
— "Preferences", "Keyboard Shortcuts", "About Music", every
`ShortcutsDialog` section/item label, every `PreferencesDialog` row title and
subtitle, `AboutDialog`'s strings — is a hardcoded English literal. Nothing
changed on this axis since the prior pass's `.reports/parity-translation-parity.md`,
which already reached this same conclusion; this pass re-derives it directly
rather than citing that document as the source.

## What this means against the skill's three claims

1. **Key sets equal?** No. Port key set is empty. 0 of however many msgids
   `xgettext` would extract from the port's 45-upstream-file-equivalent
   source have a marker of any kind.
2. **Byte-identical keys?** Not applicable — there is nothing to compare.
3. **Languages ship?** No. 0 of 74 `.po` catalogues exist in the port, and
   there is no `.mo` build/install step, in the `Rakefile`, the gemspec, or
   anywhere else (checked: `grep -n "mo\b\|gettext\|i18n" Rakefile
   gnome-music-rb.gemspec` returns nothing relevant).

## Newly checked this pass: a few strings are byte-identical to upstream by coincidence, most are rewritten

A handful of the port's literals happen to match upstream's English exactly
(e.g. `'Preferences'`, `'About Music'`, `'Keyboard Shortcuts'`), which is
irrelevant to parity because none of them is marked — an unmarked literal
cannot be extracted into a catalogue no matter how closely it matches
upstream's wording. Most others differ even in wording, which would be a
second, independent gap if either side had a catalogue to compare against
(there is only one, upstream's, so every port string is simply unextracted,
full stop):

| Upstream (`_()`) | Port literal | 
|---|---|
| `_("Repeat")`-class combo entries, upstream's `gnomemusic/player.py` `RepeatMode` enum labels (`"None"`, `"Song"`, `"All"`) feeding translated strings in the UI | `REPEAT_MODES = %w[None Song All Shuffle].freeze` — plain untranslated Ruby strings, and `'Shuffle'` is a fourth entry upstream's combo does not have in the same form (upstream's repeat UI is a toggle + separate shuffle action, not a 4-way combo — a real UI-shape difference worth a component-parity look, filed there, not here) |
| `_("Preferences")` | `'Preferences'` | unmarked, matches by luck |
| `_("ReplayGain")`-adjacent subtitle text | `'Balance loudness between songs if ReplayGain metadata is found'` — reworded/invented, not upstream's string | two gaps if there were a catalogue: wrong msgid, and the feature it describes (ReplayGain) does not actually process audio in this port either (see `parity-component-parity.md`) |

## Already disclosed, re-checked for honest framing this pass

The prior pass's own translation report already flagged the earlier
component-inventory document's phrasing ("a separate step", "out of scope
for this survey") as the exact pattern `accountability-ensurance` exists to
catch. That document is unchanged this pass (not re-edited), so the flag
stands; see `.reports/parity-accountability.md` in this pass for the fuller
sweep, which finds several more instances of the same pattern directly in
`lib/` source comments that the prior pass's translation report did not
cover (it only looked at `.reports/`).

## Verdict

Translation parity is **not met**, as completely as this axis can fail, same
as the prior pass: 0 marked strings, 0 catalogues, 0 languages, no
infrastructure to extract or compile either. Nothing landed on this axis
between the two passes — none of the three commits since the last audit
(`f879f4cd`, `c0847d38`, `1dc12993`) touch translation at all.
