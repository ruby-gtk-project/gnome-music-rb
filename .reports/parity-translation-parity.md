# Translation parity — gnome-music-rb vs upstream `origin/master`

## Upstream census

```
git ls-tree -r --name-only origin/master | grep '^po/.*\.po$' | wc -l   → 74
git show origin/master:po/POTFILES.in | wc -l                           → 45 files marked for extraction
git show origin/master:gnomemusic/application.py | grep gettext         → from gettext import gettext as _
```

Upstream marks user-visible strings with `gettext`'s `_()` throughout
`gnomemusic/` (confirmed in `application.py`: `GLib.set_application_name(_("Music"))`
and similar elsewhere) and ships **74 translated `.po` catalogues** plus
`po/LINGUAS` (74 language codes) and `po/POTFILES.in`/`po/POTFILES.skip`
driving `xgettext` extraction from 45 source files.

## Port census

```
find . -iname '*.po' -o -iname '*.pot'                     → no results, anywhere in the repo
grep -rn "gettext\|FastGettext\|_(\"" lib/ exe/             → no results
find data -type f                                          → icon/SVG assets only, no po/ directory, no .mo build step
```

**Zero.** No translation marker of any kind appears anywhere in `lib/` or
`exe/`. No `.po`, `.pot`, or `.mo` file exists in the repository. No
gettext-equivalent gem (`gettext`, `fast_gettext`, `r18n`, anything) is
required or referenced. Every user-visible string enumerated in
`.reports/component-inventory.md`'s own widget tables — "Welcome to
Music", "Play", "Add to _Favorite Songs", every dialog title, every menu
item, every status page message — is a hardcoded English literal in the
Ruby source.

## What this means against the skill's three claims

1. **Key sets equal?** No — the port's key set is the empty set. 0 of
   however-many msgids upstream extracts from those 45 files have any
   counterpart marker in the port.
2. **Byte-identical keys?** Not applicable; there are no keys to compare.
3. **Languages come with it?** No — 0 of 74 `.po` catalogues exist in the
   port, and there is no build step that would compile or install a `.mo`
   even if one did.

This is not a case of "close but reworded" — it is total absence of
internationalization infrastructure. **All 74 languages upstream ships are
unsupported in the port**, and the English strings themselves are not even
marked as translatable, so adding a single language later would require
retrofitting every string in all 68 `lib/*.rb` files, not just adding
catalogues.

## Already disclosed, but worth restating plainly

`.reports/component-inventory.md` already says this in its blockers
section ("Translations. 74 po/ catalogues upstream; the port has no
gettext setup at all. Translation parity is a separate step.") and in its
closing scope table ("`po/` (74 catalogues)... out of scope for this
survey"). That framing — "a separate step", "out of scope for this
survey" — is exactly the pattern `accountability-ensurance` exists to
catch: it reads as a scheduled future task rather than as the complete,
currently-missing absence that it is. There is no partial credit and no
later phase that makes this not a gap today. See
`.reports/parity-accountability.md`.

## Verdict

Translation parity is **not met**, as completely as this axis can fail:
0 marked strings, 0 catalogues, 0 languages, no infrastructure to extract
or compile either.
