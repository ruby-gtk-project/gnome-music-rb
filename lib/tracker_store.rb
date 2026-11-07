# frozen_string_literal: true

require 'adwaita'
require 'fileutils'
require 'gio2'
require 'tsparql'
require_relative 'music_logger'

# TrackerStore is the connection to the local Tracker (TinySparql) database
# this port's own data lives in.
#
# Ported from the local-database half of upstream's gnomemusic/trackerwrapper.py
# (TrackerWrapper._setup_local_db / update_tag). Upstream also opens a second
# connection to the session-wide Tracker indexer (`Tracker.SparqlConnection.bus_new`)
# to read the user's music collection; that half is not here; see
# core_model.rb for why.
#
# `Tsparql::SparqlConnection.bus_new_async` is the only binding for that bus
# connection, and its block hands back a `Gio::Task` with no matching
# `bus_new_finish` anywhere in the gem (checked: neither
# `Tsparql::SparqlConnection` nor the `Tsparql` module define one), and
# `Gio::Task` itself exposes only the untyped `propagate_pointer` — the same
# gap `store_art.rb` already documents for `GdkPixbuf::Pixbuf`. So the bus
# connection cannot be obtained through this gem as it is bound today.
#
# The plain, synchronous `Tsparql::SparqlConnection.new(flags, file, ontology,
# cancellable)` constructor has no such gap — it is a real GI constructor
# that raises GLib::Error on failure — and that is the one upstream's local
# database also uses, so this class sticks to it.
class TrackerStore
  def self.instance
    @instance ||= new
  end

  def initialize(logger: nil)
    @log = logger || MusicLogger.new
    @connection = open_connection
  end

  # Writes the favorite tag for a song's Tracker resource, matching
  # upstream's TrackerWrapper#_update_favorite. `urn` is the CoreSong's id;
  # a song with no real Tracker urn (nothing loads the collection into
  # Tracker yet; see core_model.rb) still runs the query, which simply
  # describes a resource Tracker has never seen.
  def update_favorite(urn, favorite)
    @connection.then do |connection|
      if favorite
        connection.update(
          "INSERT DATA { <#{urn}> a nmm:MusicPiece ; " \
          "nao:hasTag nao:predefined-tag-favorite . }",
        )
      else
        connection.update(
          "DELETE DATA { <#{urn}> nao:hasTag nao:predefined-tag-favorite . }",
        )
      end
    end
  rescue GLib::Error => e
    @log.warning("Unable to update favorite: #{e.domain}, #{e.message}")
  end

  private

    # $XDG_CACHE_HOME (or ~/.cache)/gnome-music/db, matching upstream's
    # TrackerWrapper#cache_directory (GLib.get_user_cache_dir there; the
    # Ruby bindings have no GLib.get_user_cache_dir, only
    # GLib.get_user_special_dir for the XDG user *directories*, which cache
    # is not one of).
    def cache_directory
      File.join(ENV['XDG_CACHE_HOME'] || File.join(Dir.home, '.cache'), 'gnome-music', 'db')
    end

    def open_connection
      FileUtils.mkdir_p(cache_directory)
      Tsparql::SparqlConnection.new(
        Tsparql::SparqlConnectionFlags::NONE,
        Gio::File.new_for_path(cache_directory),
        Tsparql.sparql_get_ontology_nepomuk,
        nil,
      )
    rescue GLib::Error => e
      @log.warning("Error opening Tracker local database: #{e.domain}, #{e.message}")
      nil
    end
end
