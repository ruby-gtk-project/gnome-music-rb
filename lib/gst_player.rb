# frozen_string_literal: true

require 'adwaita'
require_relative 'music_logger'

# Playback status, upstream's gstplayer.Playback.
module Playback
  STOPPED = 0
  LOADING = 1
  PAUSED = 2
  PLAYING = 3
end

# GstPlayer contains the GStreamer logic for Player.
#
# Ported from upstream's gnomemusic/gstplayer.py: it owns the pipeline, maps
# it onto the four Playback states, reports position and duration in seconds,
# carries volume and mute, and tells the Player when the stream starts, when
# it ends and when it fails.
#
# Upstream builds a playbin3 pipeline directly through the Gst bindings. There
# are no Gst bindings for Ruby, so the pipeline here is Gtk::MediaFile, which
# is GTK's own GStreamer-backed media stream, and the bus messages upstream
# watches become property notifications on that stream.
#
# Two pieces of upstream's pipeline have no equivalent in the GTK media API
# and are therefore not here: ReplayGain, which upstream inserts as an
# rgvolume/rglimiter filter bin, and the "about to finish" callback it uses
# for gapless playback. The ReplayGain preference is still stored, and the
# player advances on end of stream instead of pre-loading the next song.
# Missing-codec installation, which upstream drives through PackageKit, is
# likewise out: a stream that cannot be decoded reports an error, which is
# what marks the song as failed.
class GstPlayer
  CLOCK_INTERVAL = 1000

  def initialize(logger)
    @log = logger
    @state = Playback::STOPPED
    @duration = -1.0
    @tick = 0
    @clock_id = 0
    @seeking = false
    @listeners = Hash.new { |hash, key| hash[key] = [] }
  end

  # Registers a listener for one of the player's events: :eos, :error,
  # :clock_tick, :seek_finished or :stream_start.
  def on(event, &block)
    @listeners[event] << block
    block
  end

  def media
    @media ||= Gtk::MediaFile.new.tap do |stream|
      stream.signal_connect('notify::ended') { on_ended }
      stream.signal_connect('notify::error') { on_error }
      stream.signal_connect('notify::prepared') { on_prepared }
      stream.signal_connect('notify::duration') { query_duration }
      stream.signal_connect('notify::seeking') { on_seeking }
    end
  end

  def state = @state

  def state=(state)
    case state
    when Playback::PAUSED then pause_media
    when Playback::STOPPED then stop_media
    when Playback::LOADING then load_media
    when Playback::PLAYING then play_media
    end
  end

  def url = @url

  def url=(url)
    @url = url
    @duration = -1.0
    media.file = Gio::File.new_for_uri(url)
  end

  # Player position in seconds.
  def position = media.timestamp / 1_000_000.0

  # Total duration of the current media in seconds, or -1 when it is not
  # known yet.
  def duration
    if @state == Playback::STOPPED
      -1.0
    else
      @duration
    end
  end

  def volume = media.volume

  def volume=(value)
    media.volume = value
  end

  def mute? = media.muted?

  def mute=(value)
    media.muted = value
  end

  # Seeks to a position in seconds.
  def seek(seconds)
    @seeking = true
    media.seek((seconds * 1_000_000).to_i)
  end

  private

    def emit(event, *args)
      @listeners[event].dup.each { |listener| listener.call(*args) }
    end

    def play_media
      media.play
      change_state(Playback::PLAYING)
      create_clock_tick
    end

    def pause_media
      media.pause
      change_state(Playback::PAUSED)
      destroy_clock_tick
    end

    def load_media
      media.pause
      change_state(Playback::LOADING)
    end

    def stop_media
      media.tap do |stream|
        stream.pause
        stream.seek(0)
      end
      change_state(Playback::STOPPED)
      destroy_clock_tick
    end

    def change_state(state)
      @log.debug("Player state changed: #{@state} -> #{state}")
      @state = state
      emit(:state_changed)
    end

    def query_duration
      (media.duration / 1_000_000.0).then do |duration|
        if duration != @duration
          @duration = duration
          @log.debug("duration changed: #{@duration}")
          emit(:duration_changed)
        end
      end
    end

    def on_prepared
      if media.prepared?
        @tick = 0
        query_duration
        emit(:stream_start)
      end
    end

    def on_ended
      if media.ended?
        emit(:eos)
      end
    end

    def on_error
      media.error.then do |error|
        if error
          @log.warning("URI: #{@url}")
          @log.warning("Error from the media stream: #{error.message}")
          emit(:error)
        end
      end
    end

    def on_seeking
      if !media.seeking? && @seeking
        @seeking = false
        emit(:seek_finished)
      end
    end

    def create_clock_tick
      if @clock_id.zero?
        @clock_id = GLib::Timeout.add(CLOCK_INTERVAL) do
          emit(:clock_tick, @tick)
          @tick += 1
          true
        end
      end
    end

    def destroy_clock_tick
      unless @clock_id.zero?
        GLib::Source.remove(@clock_id)
        @clock_id = 0
      end
    end
end
