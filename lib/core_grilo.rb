# frozen_string_literal: true

require 'grilo'
require_relative 'music_logger'

# CoreGrilo sets up the Grilo plugin registry and asks its remote cover
# sources for an album's thumbnail.
#
# Ported from the cover-lookup half of upstream's gnomemusic/coregrilo.py:
# `Grl.init`, a `Grl::Registry`, the `grl-lua-factory` config that turns on
# `grl-theaudiodb-cover`, loading every plugin and asking each known cover
# source (`grl-musicbrainz-coverart`, `grl-lastfm-cover`,
# `grl-theaudiodb-cover`) to `#resolve` a thumbnail for an artist/album pair.
#
# Upstream's CoreGrilo does two more things this class does not. First, it
# also owns a TrackerWrapper and drives LocalSearchWrapper, the
# Tsparql-prepared-statement library browser bound to the session Tracker
# miner's bus connection — that connection needs
# `Tracker.SparqlConnection.bus_new`, which this port's `tsparql` gem cannot
# open (no `bus_new_finish`; see tracker_store.rb), so browsing the
# collection through Grilo/Tracker is not ported. Second, on a resolved
# cover it hands the thumbnail's remote URL to StoreArt to download and
# cache; StoreArt is deliberately not required anywhere live yet (see its
# own file), so a resolved cover here is only logged.
#
# `Grl::Source#resolve`, which every one of those three lookups ultimately
# calls, cannot actually be called through this gem's binding: its `keys`
# argument is a GList of guint32 (Grl's metadata key ids), and
# gobject-introspection's Ruby marshalling of that argument direction is not
# implemented —
#   "TODO: [keys] in Ruby -> GIArgument(glist)[guint32][nothing]"
# — raised as a Ruby NotImplementedError every time, regardless of which
# source is asked. That is caught and logged per source below rather than
# left to crash the caller. Registry setup, config and source discovery all
# work; only the one call that would fetch an actual thumbnail does not.
class CoreGrilo
  # Upstream's cover source ids, ranked musicbrainz > lastfm > theaudiodb
  # (`_grl_plugin_ranks`). `source.supported_keys` would be the generic way
  # to find these (what upstream's `_on_source_added` checks), but that
  # getter has the same GList<guint32> marshalling gap `#resolve` does, so
  # the known ids are used directly instead.
  THUMBNAIL_SOURCE_IDS = %w[grl-musicbrainz-coverart grl-lastfm-cover grl-theaudiodb-cover].freeze

  THEAUDIODB_API_KEY = '195003'

  METADATA_KEYS = [Grl::METADATA_KEY_ID, Grl::METADATA_KEY_THUMBNAIL].freeze

  def self.instance
    @instance ||= new
  end

  def initialize(logger: nil)
    @log = logger || MusicLogger.new
    @thumbnail_sources = setup_registry
  end

  # Asks every known remote cover source to resolve a thumbnail for the
  # given album/artist, matching upstream's #get_album_art. Calls `block`
  # with the resolved thumbnail uri on success; see the class comment for
  # why that currently never happens.
  def resolve_album_cover(title, artist, &block)
    @thumbnail_sources.each do |source|
      resolve_on(source, title, artist, &block)
    end
  end

  private

    def resolve_on(source, title, artist, &block)
      media = Grl::Media.new!
      media.set_album(title.to_s)
      media.set_artist(artist.to_s)

      source.resolve(media, METADATA_KEYS, fast_options) do |_src, _op_id, resolved, error|
        if error
          @log.warning("Error resolving cover from #{source.source_id}: #{error.domain}, #{error.message}")
        elsif resolved
          block&.call(resolved.thumbnail)
        end
      end
    rescue NotImplementedError => e
      @log.warning("Grl::Source#resolve is not usable through this binding (#{source.source_id}): #{e.message}")
    end

    def fast_options
      @fast_options ||= Grl::OperationOptions.new!.tap do |options|
        options.set_resolution_flags(Grl::ResolutionFlags::FAST_ONLY | Grl::ResolutionFlags::IDLE_RELAY)
      end
    end

    def setup_registry
      Grl.init([])
      registry = Grl::Registry.default
      registry.add_config(theaudiodb_config)
      registry.load_all_plugins(true)
      registry.get_sources(Grl::TypeFilter::ALL).select { |s| THUMBNAIL_SOURCE_IDS.include?(s.source_id) }
    rescue GLib::Error => e
      @log.warning("Error initializing the Grilo registry: #{e.domain}, #{e.message}")
      []
    end

    def theaudiodb_config
      Grl::Config.new!.tap do |config|
        config.set_plugin('grl-lua-factory')
        config.set_source('grl-theaudiodb-cover')
        config.set_api_key(THEAUDIODB_API_KEY)
      end
    end
end
