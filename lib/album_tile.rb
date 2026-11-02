# frozen_string_literal: true

require 'adwaita'
require_relative 'core_album'
require_relative 'cover_paintable'
require_relative 'utils'

# AlbumTile is the cover, album title and artist name shown in the albums
# grid and in the search results.
#
# Ported from upstream's gnomemusic/widgets/albumtile.py and
# data/ui/AlbumTile.ui.
#
# The cover is a CoverPaintable, as upstream's is: it shows the placeholder
# icon until the art pipeline has found the album's artwork and fills itself
# in when it has.
class AlbumTile < Gtk::Box
  SIZE = Utils::ART_SIZES[:medium]

  def initialize
    super(:vertical, 0)

    @corealbum = nil
    self.has_tooltip = true
    self.valign = :start
  end

  def build
    tap do |box|
      box.append(cover_image)
      box.append(album_label)
      box.append(artist_label)
    end
  end

  def corealbum = @corealbum

  def corealbum=(corealbum)
    @corealbum = corealbum

    album_label.tap do |label|
      label.label = corealbum.title.to_s
      label.tooltip_text = corealbum.title.to_s
    end

    artist_label.tap do |label|
      label.label = corealbum.artist.to_s
      label.tooltip_text = corealbum.artist.to_s
    end

    cover_paintable.coreobject = corealbum
  end

  def cover_paintable = @cover_paintable ||= CoverPaintable.new(self, SIZE, :album)

  def cover_image
    @cover_image ||= Gtk::Image.new.tap do |image|
      image.paintable = cover_paintable
      image.set_size_request(SIZE.width, SIZE.height)
      image.pixel_size = SIZE.height
      image.vexpand = true
      image.valign = :center
      image.halign = :center
      image.add_css_class('tile-image')
    end
  end

  def album_label
    @album_label ||= Gtk::Label.new.tap do |label|
      label.justify = :center
      label.wrap = true
      label.ellipsize = :middle
      label.max_width_chars = 20
      label.lines = 1
    end
  end

  def artist_label
    @artist_label ||= Gtk::Label.new.tap do |label|
      label.ellipsize = :middle
      label.max_width_chars = 20
      label.add_css_class('artist-label')
      label.add_css_class('dim-label')
    end
  end
end
