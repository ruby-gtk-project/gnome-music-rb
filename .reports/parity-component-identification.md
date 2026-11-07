# Component identification — gnome-music-rb vs upstream `origin/master`

> The brief names `origin/main` as the upstream ref. That ref does not exist
> in this clone (`git show origin/main:...` fails with "invalid object
> name"). The only candidate upstream ref is `origin/master`, which is what
> `.reports/component-inventory.md` already used and what this audit uses
> too. Recording this again here because a ref that silently doesn't exist
> is exactly the kind of thing a later run could paper over.

## Inventory counts (upstream, `origin/master`)

| Kind | Count | Source |
|---|---:|---|
| Python modules under `gnomemusic/` | 73 | `git ls-tree -r --name-only origin/master \| grep '^gnomemusic/.*\.py$' \| wc -l` |
| `.ui` files under `data/ui/` | 33 | same, `grep '\.ui$'` |
| `po/*.po` catalogues | 74 | `git ls-tree -r --name-only origin/master \| grep '^po/.*\.po$' \| wc -l` |
| Files listed in `po/POTFILES.in` | 45 | `git show origin/master:po/POTFILES.in \| wc -l` |
| Automated tests (any framework) upstream | 0 | no `tests/`, no `meson test(...)`, no `*_test.py`/`conftest.py` found anywhere in the `origin/master` tree |

## Inventory counts (port, `ruby` branch, this audit)

| Kind | Count | Source |
|---|---:|---|
| `lib/*.rb` files | 68 | `find lib -name '*.rb' \| wc -l` |
| `*_spec.rb` files | 0 | `find . -name '*_spec.rb'` returns nothing; `spec/` holds only `spec_helper.rb` and a README describing the harness, no actual specs |
| `test/drive_*.rb` scripts | 3 (`drive_smoke.rb`, `drive_artwork.rb`, `drive_music.rb`) plus the shared `gtk_driver.rb` harness | `ls test/` |
| `.po`/`.pot` files anywhere in the port | 0 | `find . -iname '*.po' -o -iname '*.pot'` |
| `TODO`/`FIXME`/"not implemented" hits in `lib/`, `exe/` | 1 (`get_flags`, documented as a genuine binding limitation, see accountability report) | grep |

## Upstream component map used for this audit

This audit reuses the component pairing already established in
`.reports/component-inventory.md` (one `.ui` + its `.py` class, or a
standalone `.py`/`.ui`, = one upstream component = one `lib/*.rb`). That
document's per-component table is **not** re-derived here; it is read and
checked against the current state of `lib/` as of this audit's HEAD
(`c5c22b77`). Where this audit's findings disagree with that document's
"present" marks, the disagreement is called out explicitly in
`.reports/parity-component-parity.md` rather than silently overwritten.

New components are not expected since that document's writing — no new
upstream commits were pulled (the task forbids checking out or merging
`origin/main`/`origin/master`), and `lib/` grew by exactly one file
(`lib/disc_list_item.rb`, for `Gtk.ListItem` disc-row templates) since that
document's last revision.

## What this audit adds beyond re-stating the inventory

The existing inventory document scopes translation and test parity as "out
of scope for this survey" (see its closing table). That scoping is not
carried forward here — those two axes are this audit's explicit job, and
they are covered in `.reports/parity-test-parity.md` and
`.reports/parity-translation-parity.md`.
