# frozen_string_literal: true

require 'adwaita'
require_relative 'media_art_loader'
require_relative 'music_logger'

# TextureCache is the retrieval and cache for artwork textures.
#
# Ported from upstream's gnomemusic/texturecache.py. Every cover holds its own
# TextureCache instance to look a uri up with, while the textures themselves
# live in one table shared by the class: Music has two cycling views of around
# two hundred items each, so the table has to outlast any one cover to be
# worth having. Entries are stamped with the time they were last handed out,
# a timer evicts the oldest ones every ten seconds, and a low memory warning
# from the session shrinks the table to nothing until the pressure passes.
#
# An evicted entry is marked CLEARED rather than dropped, which is how
# upstream distinguishes "nothing is cached, look it up again" from "there is
# no art at this uri", the UNAVAILABLE state a second lookup must not retry.
#
# Where upstream emits a "texture" signal, this registers listener blocks:
# the Ruby bindings cannot install GObject signals on a Ruby class.
class TextureCache
  # The loading state of a uri: AVAILABLE is cached, UNAVAILABLE has no art,
  # CLEARED was cached and was evicted.
  AVAILABLE = 0
  UNAVAILABLE = 1
  CLEARED = 2

  # Larger than the two cycling views combined, or the cache buys nothing.
  MAX_CACHE_SIZE = 800
  CLEANUP_INTERVAL = 10

  Entry = Data.define(:state, :accessed_at, :texture)

  class << self
    def log = @log ||= MusicLogger.new
    def textures = @textures ||= {}
    def size = @size ||= MAX_CACHE_SIZE

    # Installs the eviction timer and the memory monitor once, the first time
    # a cache is built.
    def start_cleanup
      unless @cleanup_started
        @cleanup_started = true
        GLib::Timeout.add_seconds(CLEANUP_INTERVAL) { cache_cleanup }
        watch_memory
      end
    end

    # A session under memory pressure gets a cache of one entry, which the
    # next sweep empties; anything below the lowest warning level restores
    # the full size.
    def watch_memory
      memory_monitor.signal_connect('low-memory-warning') do |_monitor, level|
        if level.to_i < Gio::MemoryMonitorWarningLevel::LOW.to_i
          @size = MAX_CACHE_SIZE
        else
          @size = 1
        end
      end
    end

    def memory_monitor = @memory_monitor ||= Gio::MemoryMonitor.dup_default

    # Sorts the available entries by recency and clears the oldest ones to
    # bring the table down to the maximum size.
    def cache_cleanup
      available.then do |sorted|
        if sorted.length >= size
          clear_oldest(sorted)
        end
      end

      true
    end

    def available
      textures.select { |_uri, entry| entry.state == AVAILABLE }
              .sort_by { |_uri, entry| entry.accessed_at }
    end

    def clear_oldest(sorted)
      sorted[0...-size].each do |uri, entry|
        textures[uri] = Entry.new(state: CLEARED, accessed_at: entry.accessed_at, texture: nil)
      end.length.then do |cleared|
        log.info(
          "Cleared #{cleared} items, texture cache contains " \
          "#{sorted.length - cleared} available items.",
        )
      end
    end

    def store(uri, texture)
      if texture
        textures[uri] = Entry.new(state: AVAILABLE, accessed_at: Time.now.to_f, texture: texture)
      else
        textures[uri] = Entry.new(state: UNAVAILABLE, accessed_at: Time.now.to_f, texture: nil)
      end
    end

    # The cached entry for a uri when it answers the question, and nil when
    # the uri has to be read.
    def settled_entry(uri)
      textures[uri].then do |entry|
        if entry && [AVAILABLE, UNAVAILABLE].include?(entry.state)
          entry
        end
      end
    end

    def touch(uri, entry)
      textures[uri] = Entry.new(state: entry.state, accessed_at: Time.now.to_f, texture: entry.texture)
    end
  end

  def initialize
    @art_loader = nil
    @listeners = []
    self.class.start_cleanup
  end

  # Registers a listener for a finished lookup. The block is called with the
  # texture, or with nil when the uri carries no art.
  def on_texture(&block)
    @listeners << block
    block
  end

  # Drops the lookup in flight, so a cover that has been handed a new object
  # is not painted with the art of the old one.
  def clear_pending_lookup_callback
    @art_loader.then do |loader|
      if loader
        loader.cancel
        @art_loader = nil
      end
    end
  end

  # Looks a texture up for the given MediaArt uri.
  def lookup(uri)
    clear_pending_lookup_callback

    self.class.settled_entry(uri).then do |entry|
      if entry
        self.class.touch(uri, entry)
        announce(entry.texture)
      else
        load(uri)
      end
    end
  end

  private

    def load(uri)
      MediaArtLoader.new.tap do |loader|
        @art_loader = loader
        loader.on_finished do |texture|
          if @art_loader.equal?(loader)
            @art_loader = nil
            self.class.store(uri, texture)
            announce(texture)
          end
        end
        loader.start(uri)
      end
    end

    def announce(texture)
      @listeners.dup.each { |listener| listener.call(texture) }
    end
end
