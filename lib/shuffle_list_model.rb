# frozen_string_literal: true

require 'adwaita'
require_relative 'music_logger'

# ShuffleListModel shuffles the queue.
#
# Ported from upstream's gnomemusic/shufflelistmodel.py: it keeps a list of
# positions into the underlying model and reorders that list rather than the
# model itself. Shuffling only touches the items after the current position,
# and deshuffling only re-sorts what is still ahead in the queue.
#
# Upstream implements Gio.ListModel so views can bind to it directly. The Ruby
# bindings cannot register a Ruby class as a Gio::ListModel implementation, so
# this is a plain wrapper with the same get_item/n_items surface; the queue is
# its only consumer, and no view binds to it.
class ShuffleListModel
  attr_reader :shuffle_values

  def initialize(model)
    @log = MusicLogger.new
    @model = model
    @shuffled = false
    @shuffle_values = (0...model.n_items).to_a

    @model.signal_connect('items-changed') { on_items_changed }
  end

  def shuffled? = @shuffled

  def n_items = @model.n_items

  def get_item(position)
    @shuffle_values[position].then do |index|
      if index
        @model.get_item(index)
      end
    end
  end

  def each
    (0...n_items).each { |position| yield(get_item(position)) }
  end

  def to_a = (0...n_items).map { |position| get_item(position) }

  # Shuffles the items after the given position, putting the song at
  # initial_song_position first.
  def shuffle(position, initial_song_position = 0)
    @shuffled = true

    if @model.n_items.positive?
      @shuffle_values[0..position].then do |list_before|
        @shuffle_values[(position + 1)..].to_a.shuffle.then do |list_after|
          @shuffle_values = list_before + list_after
        end
      end

      @shuffle_values.delete(initial_song_position)
      @shuffle_values = [initial_song_position] + @shuffle_values
      @log.debug("Shuffled order: #{@shuffle_values}")
    end
  end

  # Deshuffles the model, from the given position on when one is given.
  def deshuffle(position = nil)
    @shuffled = false

    if position
      @shuffle_values[0...position].then do |list_before|
        @shuffle_values[position, 1].to_a.then do |list_position|
          @shuffle_values[(position + 1)..].to_a.sort.then do |list_after|
            @shuffle_values = list_before + list_position + list_after
          end
        end
      end
    else
      @shuffle_values = @shuffle_values.sort
    end

    @log.debug("Deshuffled order: #{@shuffle_values}")
  end

  private

    # Item changes during play are not tracked position by position upstream
    # either; the shuffle list is rebuilt for the new length.
    def on_items_changed
      @shuffle_values = (0...@model.n_items).to_a
    end
end
