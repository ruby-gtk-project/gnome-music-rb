# Binding gap: playing a song crashes the process

Found while writing `test/drive_music.rb` (the GtkDriver-shaped headless
drive script) and confirmed by deliberately firing the action.

## Symptom

Calling `Player#play` with a `CoreSong` whose `url` does not resolve to a
real, decodable file — which is every song in this fork's test fixtures,
and would be true of any file Tracker has not actually indexed yet — kills
the whole Ruby process with a segfault. It is not a raised exception; there
is nothing for the port to rescue.

Reproduced by firing `win.playlist_play` (also reachable through
`app.play_pause`, double-clicking any song row, or the album/playlist "Play"
button) against the fixture songs used by `test/drive_smoke.rb` and
`test/drive_music.rb` (`file:///tmp/one.ogg`, a URI that is never actually
written to disk).

```
Gtk-CRITICAL **: gtk_gst_media_file_source_setup_cb: assertion 'stream != NULL' failed
[BUG] Segmentation fault at 0x0000000000000030
...
libruby-3.4.9.so.3.4(rb_funcallv+0xb1)
glib2.so(rbglib_log_handler+0xd3)
libglib-2.0.so.0(g_logv+...)
libglib-2.0.so.0(g_log+...)
libgobject-2.0.so.0(g_closure_invoke+...)
libgobject-2.0.so.0(signal_emit_unlocked_R...)
```

## Cause

`lib/gst_player.rb` is explicit about why: there are no GStreamer (`Gst`)
bindings for Ruby, so GnomeMusic's own gstreamer pipeline (`playbin3` in
upstream's `gnomemusic/gstplayer.py`) is replaced here with `Gtk::MediaFile`,
GTK's own GStreamer-backed media stream. When `Gtk::MediaFile`'s internal
GStreamer source fails to set up — here, because the file genuinely does
not exist — its setup callback runs on a GStreamer worker thread, not the
GLib main thread. That callback logs a `GLib::CRITICAL` message, and
ruby-gnome's log handler (`rbglib_log_handler` in `glib2.so`) calls back
into the Ruby VM to format and emit it. Calling into the Ruby VM from a
thread the VM does not own is unsafe and segfaults
(`rb_funcallv` inside the signal handler's C backtrace).

This is a `glib2`/`Gtk::MediaFile` binding hazard (a GStreamer-threaded
callback reentering the Ruby VM through the log handler), not a mistake in
this port's Ruby code — the same call into `Gtk::MediaFile` would crash any
ruby-gnome program that hit a GStreamer setup failure on a background
thread. It cannot be fixed by catching an exception in `Player#play`,
`GstPlayer#url=` or anywhere else in this codebase, because the process dies
before any Ruby frame on the calling thread gets a chance to run — the crash
happens on GStreamer's own thread, inside glib2's C log handler.

## What this means for the test suites

`test/drive_smoke.rb`, `test/drive_artwork.rb` and `test/drive_music.rb` all
deliberately avoid calling `Player#play` (or anything that reaches it —
`win.playlist_play`, `app.play_pause`, activating a song row) for exactly
this reason. `test/drive_music.rb` documents the hazard in a trailing
comment rather than driving it, per the testing skill's instruction not to
report a crash as a passing (or silently skipped) check.

## Suggested next step for a future porting pass

Nothing in this port's control fixes the crash; the fix, if one is wanted,
belongs upstream in `glib2` (making `rbglib_log_handler` thread-safe, or at
least not reentering the VM from a foreign thread) or in how `Gtk::MediaFile`
is driven (keeping its setup errors off any thread that was not started by
the Ruby VM). Until then, the port should treat any code path that can reach
`Player#play` with an unverified URL as something that can take the whole
process down, and the test suites should keep steering clear of it instead
of wrapping it in a rescue that cannot run before the crash in the first
place.
