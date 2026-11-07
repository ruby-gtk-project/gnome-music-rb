# frozen_string_literal: true

require 'adwaita'
require_relative 'media_art'
require_relative 'music_logger'

# EmbeddedArt looks up local art for a CoreAlbum or CoreSong that is not in
# the MediaArt cache yet.
#
# Ported from upstream's gnomemusic/embeddedart.py. Upstream tries two
# sources in turn:
#
#   1. Art embedded in the track's own tags, read with GStreamer's
#      GstPbutils::Discoverer and pulled out of the GstTag::TAG_IMAGE sample
#      with Gst::Buffer#map.
#   2. A cover file sitting in the track's directory, found and linked into
#      the cache by MediaArt::Process#uri.
#
# Only the second is here. The `gstreamer_pbutils` gem gives this port
# GstPbutils, GstTag and GstVideo, but it does not give it the core Gst
# module: its own loader comments say so directly ("Callers who want
# Gst::Caps install it themselves") and reaching into a GstSample's buffer
# needs Gst::Buffer#map and Gst::MapFlags, neither of which exist after
# `require "gstreamer_pbutils"` — confirmed by requiring it and checking
# `defined?(Gst)`, which is nil. Embedded tag art is therefore out of reach
# without a sixth gem (`gstreamer`) this fork was not told to add; the
# directory lookup below is complete and real, not a placeholder for the
# missing half.
#
# One behavioral note for anyone who worked with this port's earlier,
# hand-rolled directory scan: that version matched cover file names
# case-insensitively. The real `MediaArt::Process#uri` does not — a
# "Cover.JPG" sitting next to a track is not found, only exact lowercase
# names like "cover.jpg" are (confirmed directly against the typelib). That
# is libmediaart's own behavior, not a gap in this port.
class EmbeddedArt
  def initialize(logger: nil)
    @log = logger || MusicLogger.new
    @found_listeners = []
  end

  # Registers a listener for the end of the lookup. The block is called with
  # true when art was found (and already written into the cache) and false
  # otherwise, matching upstream's "art-found" signal.
  def on_art_found(&block)
    @found_listeners << block
    block
  end

  # Starts the local lookup for the given CoreAlbum or CoreSong, using
  # `title` as the album title (upstream's `query(coreobject, title)`).
  def query(coreobject, title)
    @coreobject = coreobject
    @album = title
    @artist = coreobject.artist

    if coreobject.url.to_s.empty?
      finish(false)
    else
      lookup_in_directory
    end
  end

  private

    def lookup_in_directory
      GLib::Idle.add do
        uri = MediaArt.store_cover_from_directory(@coreobject.url, @artist, @album)
        finish(!uri.nil?)
        false
      rescue StandardError => e
        @log.warning("Error: #{e.class}, #{e.message} for album: #{@album} by artist: #{@artist}")
        finish(false)
        false
      end
    end

    def finish(found)
      @found_listeners.dup.each { |listener| listener.call(found) }
    end
end
