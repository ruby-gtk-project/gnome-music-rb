# frozen_string_literal: true

require 'adwaita'
require_relative 'music_logger'

# MediaArtLoader handles retrieval of art from the MediaArt cache.
#
# Ported from upstream's gnomemusic/mediaartloader.py: it reads the file at a
# MediaArt uri in chunks off the main loop, turns the bytes into a
# Gdk::Texture and tells its listeners when it is done, handing them the
# texture or nil. A cache entry whose bytes no image loader recognises is
# deleted, as upstream does, so the next lookup fetches the art again.
#
# Upstream wraps the read in asyncio with a semaphore of ten; here the chunk
# reads are plain GIO async calls on the main loop, and the semaphore is a
# class level count of loaders in flight, so a view that cycles two hundred
# covers does not open two hundred files at once. Where upstream signals
# "finished", this registers listener blocks: the Ruby bindings cannot
# install GObject signals on a Ruby class.
class MediaArtLoader
  CHUNK_SIZE = 32_768
  MAX_IN_FLIGHT = 10

  def self.log = @log ||= MusicLogger.new

  # The loaders waiting for a slot, and how many are reading right now.
  def self.pending = @pending ||= []
  def self.in_flight = @in_flight ||= 0

  # Takes a slot for the given block, or queues it until one frees up.
  def self.acquire(&block)
    if in_flight < MAX_IN_FLIGHT
      @in_flight = in_flight + 1
      block.call
    else
      pending << block
    end
  end

  def self.release
    @in_flight = [in_flight - 1, 0].max
    pending.shift.then do |waiting|
      if waiting
        @in_flight = in_flight + 1
        waiting.call
      end
    end
  end

  def initialize
    @cancellable = Gio::Cancellable.new
    @texture = nil
    @finished = false
    @listeners = []
    @bytes = (+'').force_encoding(Encoding::BINARY)
  end

  # Registers a listener for the end of the lookup. The block is called with
  # the texture, or with nil when there is no art at the uri.
  def on_finished(&block)
    @listeners << block
    block
  end

  # Starts the cache query for the given MediaArt uri.
  def start(uri)
    @uri = uri
    @file = Gio::File.new_for_uri(uri)
    self.class.acquire { open_stream }
  end

  def cancel
    @cancellable.cancel
  end

  private

    def open_stream
      @file.read_async(GLib::PRIORITY_DEFAULT_IDLE, @cancellable) do |source, result|
        begin
          read_chunk(source.read_finish(result))
        rescue Gio::IOError::Cancelled
          abandon
        rescue StandardError => e
          warn_about(e)
          finish(nil)
        end
      end
    end

    def read_chunk(stream)
      stream.read_bytes_async(CHUNK_SIZE, GLib::PRIORITY_DEFAULT_IDLE, @cancellable) do |source, result|
        begin
          collect(stream, source.read_bytes_finish(result))
        rescue Gio::IOError::Cancelled
          close(stream)
          abandon
        rescue StandardError => e
          warn_about(e)
          close(stream)
          finish(nil)
        end
      end
    end

    def collect(stream, gbytes)
      if gbytes.size.zero?
        close(stream)
        finish(texture_from_bytes)
      else
        @bytes << gbytes.to_s
        read_chunk(stream)
      end
    end

    # A cache entry that is not an image at all is of no use to anyone, so it
    # goes the way upstream sends it.
    def texture_from_bytes
      Gdk::Texture.new(GLib::Bytes.new(@bytes))
    rescue GdkPixbuf::PixbufError::UnknownType => e
      warn_about(e)
      delete_invalid_entry
      nil
    rescue StandardError => e
      warn_about(e)
      nil
    end

    def delete_invalid_entry
      @file.delete
    rescue StandardError => e
      self.class.log.warning("Failure during removal of invalid cache item: #{e.message}")
    end

    def close(stream)
      stream.close
    rescue StandardError
      nil
    end

    # A cancelled lookup tells nobody anything, as upstream's does, but it
    # still has to hand its slot back.
    def abandon
      unless @finished
        @finished = true
        self.class.release
      end
    end

    def finish(texture)
      unless @finished
        @finished = true
        @texture = texture
        self.class.release
        @listeners.dup.each { |listener| listener.call(texture) }
      end
    end

    def warn_about(error)
      self.class.log.warning("Error: #{error.class}, #{error.message} in file: #{@uri}")
    end
end
