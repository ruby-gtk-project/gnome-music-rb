# frozen_string_literal: true

require 'adwaita'
require_relative 'core_song'
require_relative 'gst_player'
require_relative 'queue'
require_relative 'utils'

# Player is the main player object: the logic of playing a song with Music.
#
# Ported from upstream's gnomemusic/player.py. It owns the queue and the
# GStreamer wrapper, answers whether there is a next or previous song, moves
# between them, keeps the repeat mode in settings and bumps the play count
# and last-played time once a song is half way through.
#
# Upstream's gapless handling is not here: it hangs off playbin3's
# "about-to-finish" callback, which the GTK media API GstPlayer is built on
# does not expose. The player advances on end of stream instead, which is
# what upstream does for the non-gapless case.
class Player
  include Utils::Observable

  def initialize(application)
    @app = application
    @log = application.log
    @settings = application.settings
    @coremodel = application.coremodel

    @queue = PlayQueue.new(@coremodel, @log)
    @repeat = Utils::RepeatMode.from_nick(@settings['repeat'])
    @queue.repeat_mode = @repeat
    @new_clock = true
    @song_changed_listeners = []
    @seek_finished_listeners = []

    @settings.on_change('repeat') { |nick| self.repeat_mode = Utils::RepeatMode.from_nick(nick) }
    @coremodel.queue_model.signal_connect('items-changed') { on_queue_model_items_changed }

    connect_gst_player
  end

  def gst_player = @gst_player ||= GstPlayer.new(@log)

  def on_song_changed(&block)
    @song_changed_listeners << block
    block
  end

  def on_seek_finished(&block)
    @seek_finished_listeners << block
    block
  end

  def has_next? = @queue.has_next?
  def has_previous? = @queue.has_previous?
  def playing? = state == Playback::PLAYING
  def state = gst_player.state
  def duration = gst_player.duration
  def position = @queue.position
  def current_song = @queue.current_song
  def volume = gst_player.volume
  def mute? = gst_player.mute?

  def volume=(value)
    gst_player.volume = value
  end

  def mute=(value)
    gst_player.mute = value
  end

  def repeat_mode = @repeat

  def repeat_mode=(mode)
    if mode != @repeat
      @repeat = mode
      @queue.repeat_mode = mode
      @queue.repeat_mode_changed
      @settings['repeat'] = mode.nick
      notify_property(:repeat_mode)
    end
  end

  # Plays a song: the given one when there is one and it is playable, or the
  # one the play mode picks out of the queue. Called without a song while
  # paused, it resumes.
  def play(coresong = nil)
    if current_song.nil?
      @queue.set_song(coresong).then { |song| start(song) }
    else
      start(coresong)
    end
  end

  def pause
    gst_player.state = Playback::PAUSED
  end

  def stop
    gst_player.state = Playback::STOPPED
    @app.window&.set_player_visible(false)
    @queue.end
  end

  def next
    if @queue.next
      play(@queue.current_song)
    end
  end

  # Upstream restarts the current song when more than five seconds in, and
  # steps back otherwise.
  def previous
    if gst_player.position < 5 && @queue.has_previous?
      @queue.previous
      play(@queue.current_song)
    else
      set_position(0.0)
    end
  end

  def play_pause
    if state == Playback::PLAYING
      pause
    else
      play
    end
  end

  def get_position = gst_player.position

  # Changes the position within the current song. A negative position is
  # clamped to the start; past the end it does nothing.
  def set_position(position_second)
    [position_second, 0.0].max.then do |position|
      if position <= gst_player.duration
        gst_player.seek(position)
      end
    end
  end

  private

    def connect_gst_player
      gst_player.tap do |gst|
        gst.on(:clock_tick) { |tick| on_clock_tick(tick) }
        gst.on(:eos) { on_eos }
        gst.on(:error) { on_error }
        gst.on(:seek_finished) { @seek_finished_listeners.dup.each(&:call) }
        gst.on(:stream_start) { on_stream_start }
        gst.on(:state_changed) { notify_property(:state) }
        gst.on(:duration_changed) { notify_property(:duration) }
      end
    end

    def start(coresong)
      if failed?(coresong)
        on_error
      else
        load_and_play(coresong)
      end
    end

    def failed?(coresong)
      !coresong.nil? &&
        coresong.validation == CoreSong::FAILED &&
        @repeat != Utils::RepeatMode::SONG
    end

    def load_and_play(coresong)
      if coresong
        load(coresong)
      end

      if current_song
        gst_player.state = Playback::PLAYING
      end
    end

    def load(coresong)
      @log.debug("Loading song #{coresong.title}")
      gst_player.state = Playback::LOADING
      gst_player.url = coresong.url
    end

    def on_queue_model_items_changed
      if @coremodel.queue_model.n_items.zero?
        stop
      end
    end

    def on_eos
      @queue.next.then do |moved|
        if moved
          @log.debug('Song finished, loading the next one.')
          stop
          play(current_song)
        else
          @log.debug('End of the queue, stopping the player.')
          stop
        end
      end
    end

    def on_error
      stop

      current_song.then do |coresong|
        if coresong
          coresong.validation = CoreSong::FAILED
        end
      end

      if has_next? && @repeat != Utils::RepeatMode::SONG
        self.next
      end
    end

    def on_stream_start
      @song_changed_listeners.dup.each(&:call)
      notify_property(:song_changed)
    end

    def on_clock_tick(tick)
      @log.debug("Clock tick #{tick}, player at #{gst_player.position} seconds")

      if tick.zero?
        @new_clock = true
      end

      if duration.positive? && gst_player.position.positive?
        update_stats_halfway(tick)
      end
    end

    # Upstream counts a song as played once it is half way through.
    def update_stats_halfway(tick)
      (tick / duration).then do |percentage|
        if percentage > 0.5 && @new_clock
          @new_clock = false
          GLib::Idle.add { update_stats }
        end
      end
    end

    def update_stats
      current_song.then do |coresong|
        if coresong
          coresong.last_played = Time.now.utc
          coresong.bump_play_count
        end
      end

      false
    end
end
