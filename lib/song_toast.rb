# frozen_string_literal: true

require 'adwaita'

# SongToast reports a song being removed from a playlist, and offers undo.
#
# A direct port of upstream's gnomemusic/songtoast.py: the song is staged for
# deletion straight away so it leaves the list, and the deletion is either
# undone by the button or committed when the toast is dismissed.
#
# Upstream reaches the undo through a per-toast action it installs on the
# window with install_action, which the Ruby bindings do not expose; the
# toast's own button-clicked signal does the same job.
class SongToast
  def initialize(application, playlist, position, coresong)
    @application = application
    @playlist = playlist
    @position = position
    @coresong = coresong
    @undo = false
  end

  def build
    @application.window.tap do |window|
      toast.tap do |t|
        t.button_label = 'Undo'
        t.signal_connect('button-clicked') { on_undo }
        t.signal_connect('dismissed') { on_dismissed }
      end

      @playlist.stage_song_deletion(@coresong, @position)
      window.add_toast(toast)
    end

    self
  end

  def toast
    @toast ||= Adwaita::Toast.new("#{@coresong.title} removed from #{@playlist.title}")
  end

  private

    def on_undo
      @undo = true
      @playlist.undo_pending_song_deletion(@coresong, @position)
    end

    def on_dismissed
      unless @undo
        @playlist.finish_song_deletion(@coresong, @position)
      end
    end
end
