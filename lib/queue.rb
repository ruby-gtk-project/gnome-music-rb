# frozen_string_literal: true

require 'adwaita'
require_relative 'core_song'
require_relative 'utils'

# PlayQueue is the queue of songs being played.
#
# Ported from upstream's gnomemusic/queue.py: it owns the current position in
# the queue, answers whether there is a next or previous song, moves between
# them under the current repeat mode, and marks each song played, playing or
# unplayed as it goes.
#
# The class is PlayQueue rather than Queue because Ruby's ::Queue is the
# standard library's thread queue; the file still maps to upstream's queue.py.
#
# Upstream also validates songs ahead of play with a GstPbutils discoverer.
# The discoverer has no Ruby binding, so a song is validated when the player
# actually loads it: a load error marks it FAILED, which is the state the song
# rows and the skip-on-failure logic below read.
class PlayQueue
  # Type of queue, upstream's Queue.Type.
  SONGS = 0
  ALBUM = 1
  ARTIST = 2
  PLAYLIST = 3
  SEARCH_RESULT = 4

  attr_reader :position
  attr_accessor :repeat_mode

  def initialize(coremodel, logger)
    @coremodel = coremodel
    @log = logger
    @position = 0
    @repeat_mode = Utils::RepeatMode::NONE
    @model = coremodel.queue

    @coremodel.on_queue_loaded { reset_queue_state }
  end

  # Re-shuffles or re-sorts what is left of the queue, which is what upstream
  # does when the repeat mode changes.
  def repeat_mode_changed
    case @repeat_mode
    when Utils::RepeatMode::SHUFFLE then @model.shuffle(@position)
    when Utils::RepeatMode::NONE, Utils::RepeatMode::ALL then @model.deshuffle(@position)
    end
  end

  def has_next?
    @repeat_mode == Utils::RepeatMode::SONG ||
      @repeat_mode == Utils::RepeatMode::ALL ||
      @position < @model.n_items - 1
  end

  def has_previous?
    @repeat_mode == Utils::RepeatMode::SONG ||
      @repeat_mode == Utils::RepeatMode::ALL ||
      (@position <= @model.n_items - 1 && @position.positive?)
  end

  def get_next
    if has_next?
      @model.get_item(next_position)
    end
  end

  # Moves to the next song, skipping songs that failed to play.
  def next
    if has_next?
      step_to(next_position, :next)
    else
      false
    end
  end

  # Moves to the previous song, skipping songs that failed to play.
  def previous
    if has_previous?
      step_to(previous_position, :previous)
    else
      false
    end
  end

  def current_song
    @model.n_items.then do |n_items|
      if n_items.positive? && n_items > @position &&
         @model.get_item(@position)&.state == SongWidget::PLAYING
        @model.get_item(@position)
      else
        find_playing_song
      end
    end
  end

  # Sets the current song. With no song given, one is picked by the play
  # mode, which is how the play button starts an album or a playlist.
  def set_song(song)
    @model.n_items.then do |n_items|
      if n_items.zero?
        nil
      elsif song.nil?
        start_without_song(n_items)
      else
        start_with_song(song)
      end
    end
  end

  # Ends play of this queue.
  def end = reset_queue_state

  private

    def next_position
      if @repeat_mode == Utils::RepeatMode::SONG
        @position
      elsif @repeat_mode == Utils::RepeatMode::ALL && @position == @model.n_items - 1
        0
      else
        @position + 1
      end
    end

    def previous_position
      if @repeat_mode == Utils::RepeatMode::SONG
        @position
      elsif @repeat_mode == Utils::RepeatMode::ALL && @position.zero?
        @model.n_items - 1
      else
        @position - 1
      end
    end

    def step_to(new_position, direction)
      @model.get_item(@position)&.state = SongWidget::PLAYED
      @position = new_position

      @model.get_item(new_position).then do |song|
        if song.nil?
          false
        elsif song.validation == CoreSong::FAILED
          send(direction)
        else
          song.state = SongWidget::PLAYING
          true
        end
      end
    end

    def start_without_song(n_items)
      if @repeat_mode == Utils::RepeatMode::SHUFFLE
        @model.shuffle(0, rand(n_items))
      else
        @model.deshuffle
      end

      @position = 0
      @model.get_item(0).tap { |song| song.state = SongWidget::PLAYING }
    end

    def start_with_song(song)
      @model.deshuffle
      @model.to_a.index(song).then do |index|
        if index
          song_at(index).tap { |found| found.state = SongWidget::PLAYING }
        end
      end
    end

    def song_at(index)
      @model.get_item(index).tap do
        if @repeat_mode == Utils::RepeatMode::SHUFFLE
          @model.shuffle(0, index)
          @position = 0
        else
          @position = index
        end
      end
    end

    def find_playing_song
      @model.to_a.each_with_index do |coresong, index|
        if coresong.state == SongWidget::PLAYING
          @position = index
          break
        end
      end

      @model.to_a.find { |coresong| coresong.state == SongWidget::PLAYING }
    end

    def reset_queue_state
      @model.to_a.each { |coresong| coresong.state = SongWidget::UNPLAYED }
    end
end
