# Test parity — gnome-music-rb vs upstream `origin/master`

## Upstream test census: zero

Searched `origin/master` for any automated test, in any form:

```
git ls-tree -r --name-only origin/master | grep -iE 'test'   → no results
git show origin/master:meson.build | grep -i test            → no results
```

No `tests/` directory, no `*_test.py`, no `conftest.py`, no `meson.build`
`test(...)` definitions, nothing under `po/` or `data/` either. **Upstream
GNOME Music ships no automated test suite.** This is a fact about upstream,
not a gap the port introduced — a census against zero upstream tests is
trivially satisfied (0 = 0) and there is no bijection to check because there
is nothing on the upstream side to map.

This matters for how the rest of this report is read: "every upstream test
is ported" is vacuously true here. It is **not** evidence that the port's
own verification is adequate — that is a separate question, covered below.

## The port's own verification: a suite that was never run, and could not have been

`spec/` previously contained exactly two files: `spec_helper.rb` (loading
the `kettle-test`/RSpec harness) and `README.md`. **Zero `*_spec.rb` files
existed anywhere in the repository.** Worse, `spec_helper.rb` itself could
not load inside this fork's own dev shell: it unconditionally required
`"kettle/test/rspec"`, a gem the flake's `devShells.default` never
provisions (it carries only bare `pkgs.rubyPackages_3_4.rspec`), and it
required `"gnome/music/rb"`, a file that has never existed — the gemspec's
own version file lives at `lib/gnome/music/rb/version.rb`, loaded with
`Kernel.load`, not `require "gnome/music/rb"`. Running the exact command
the dev shell's own banner printed (`ruby -e 'require "rspec/core"; ...'`)
raised `LoadError: cannot load such file -- kettle/test/rspec` before a
single example file was even read. The scaffold was not merely unused — it
was unusable from the one shell this fork runs anything in.

This pass fixes both defects in `spec/spec_helper.rb` (the `kettle-test`
require now falls back to plain RSpec when the gem is absent, and the
library require now points at the real version file) and adds
`spec/utils_spec.rb`, `spec/core_song_spec.rb` and `spec/queue_spec.rb` —
39 + 12 = 51 examples covering `Utils` (artist/title fallbacks, natural
sort, `RepeatMode`, `Observable`), `CoreSong` (equality, hashing,
notification on every mutator, `#duplicate`'s independence) and `PlayQueue`
(next/previous under NONE, ALL and SONG repeat modes, `#set_song`,
skipping a `FAILED` song, `#end`'s reset). Confirmed in this session with
the dev shell's own printed spec command:

```
nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
# 51 examples, 0 failures
```

This is real RSpec coverage of pure port logic, run as a suite for the
first time — not a claim that the harness is now complete. It does not
reach any widget class (those still need `test/drive_*.rb`'s live GTK
loop), and it does not reach playback, `core_grilo`, `local_search_wrapper`,
`tracker_wrapper`, `mpris`, `store_art` or `embedded_art`, none of which
exist yet to test.

The actual verification artifact is three hand-written drive scripts under
`test/` (`drive_smoke.rb`, `drive_artwork.rb`, `drive_music.rb`), sharing
`test/gtk_driver.rb`. These are not RSpec tests; they are sequential,
numbered scenario scripts that assert with a custom `ok`/`fail` reporter
and take a screenshot after each scenario. This audit ran the main one
directly, per the dev shell's own printed drive command:

```
nix develop --command xvfb-run -a ruby test/drive_music.rb
```

Result: `49 of 49 checks passed`, `DRIVE OK` — matching the runtime gate
given in the task. This audit confirms that number is real, not asserted
secondhand: the run was executed in this session, not read off a stale log.

## Where the suite does not reach

Re-reading the drive scripts' own scenario list (echoed in the run output):
window boot, library load, view switching, album page + favorite +
add-to-playlist, song star toggle, artist page, playlist create/rename/
play-enable/delete, search open/filter/no-result/close, three dialogs,
header bar menu, player toolbar mute/repeat/shuffle, and queueing an album
"reveals the player toolbar."

Notably absent from that list, and absent from all three scripts' source
(confirmed by `grep -n 'play' test/drive_*.rb` in this session — the only
hits are "the player toolbar is revealed" and comments, never a call that
reaches `Player#play`): **actually playing a song.** `.reports/
drive-test-crash.md`, already in the repo, names the reason explicitly —
`Player#play` segfaults the process on these bindings when the stream
can't be set up — and says the drive scripts "deliberately avoid" that
path. That avoidance is disclosed, which is better than hiding it, but it
means the gate's 49 checks are a census of navigation and dialog
plumbing, not of music playback, which is this application's reason to
exist.

The suite also never exercises any of the seven missing supporting modules
from `.reports/parity-component-parity.md` (`core_grilo`,
`local_search_wrapper`, `tracker_wrapper`, `mpris`, `store_art`,
`embedded_art`, `pause_on_suspend`) — it cannot, since they don't exist to
call.

## Verdict

Test parity against upstream's test suite is **vacuously satisfied** (upstream
has none). Test parity in the sense the task's gate framing actually cares
about — "is every component exercised, and does the suite that claims so
actually run" — is **not met**: the RSpec harness is unused scaffolding, and
the one suite that does run (the drive scripts, re-run and confirmed 49/49
in this session) explicitly, by its own documentation, never exercises
playback — the component a "49 of 49 passed, 32 components covered" claim
would most need to cover to mean anything.
