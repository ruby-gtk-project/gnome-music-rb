# frozen_string_literal: true

require 'adwaita'
require_relative 'album_tile'

# AlbumCover wraps an AlbumTile for use in a flow box.
#
# A direct port of upstream's gnomemusic/widgets/albumcover.py and
# data/ui/AlbumCover.ui: a Gtk::FlowBoxChild carrying the tile, so the search
# view's flow boxes can hold the same tile the albums grid uses.
class AlbumCover < Gtk::FlowBoxChild
  attr_reader :corealbum

  def initialize(corealbum)
    super()

    @corealbum = corealbum
    add_css_class('tile')
  end

  def build
    tap do |child|
      child.child = album_tile.build
      album_tile.corealbum = @corealbum
    end
  end

  def album_tile = @album_tile ||= AlbumTile.new
end
