# frozen_string_literal: true

require 'adwaita'
require_relative 'two_line_tip'
require_relative 'utils'

# ArtistSearchTile is one artist in the search results: the artist image and
# name, with the name as a one-line tooltip.
#
# A direct port of upstream's gnomemusic/widgets/artistsearchtile.py and
# data/ui/ArtistSearchTile.ui.
#
# The image is a placeholder icon: upstream's CoverPaintable and the art
# pipeline behind it are not ported yet.
class ArtistSearchTile < Gtk::FlowBoxChild
  SIZE = Utils::ART_SIZES[:medium]

  attr_reader :coreartist

  def initialize(coreartist)
    super()

    @coreartist = coreartist
    add_css_class('tile')
  end

  def build
    tap do |child|
      child.child = box

      box.tap do |b|
        b.append(cover_image)
        b.append(artist_label)

        b.signal_connect('query-tooltip') do |_, _x, _y, _keyboard, tooltip|
          tooltip.set_custom(two_line_tip.build)
          true
        end
      end

      artist_label.label = @coreartist.artist.to_s

      two_line_tip.tap do |tip|
        tip.title = @coreartist.artist.to_s
        tip.subtitle_visible = false
      end
    end
  end

  def box
    @box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.has_tooltip = true
      box.valign = :start
    end
  end

  def cover_image
    @cover_image ||= Gtk::Image.new.tap do |image|
      image.icon_name = Utils::DEFAULT_ICONS[:artist]
      image.set_size_request(SIZE.width, SIZE.height)
      image.pixel_size = SIZE.height
      image.hexpand = true
      image.add_css_class('tile-image')
    end
  end

  def artist_label
    @artist_label ||= Gtk::Label.new.tap do |label|
      label.justify = :center
      label.wrap = true
      label.ellipsize = :middle
      label.max_width_chars = 20
      label.lines = 1
    end
  end

  def two_line_tip = @two_line_tip ||= TwoLineTip.new
end
