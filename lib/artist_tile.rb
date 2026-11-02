# frozen_string_literal: true

require 'adwaita'
require_relative 'core_artist'
require_relative 'cover_paintable'
require_relative 'utils'

# ArtistTile is one artist in the artists view sidebar.
#
# Ported from upstream's gnomemusic/widgets/artisttile.py and
# data/ui/ArtistTile.ui: the artist image and name, with a click gesture so
# the sidebar activates the row the tile belongs to.
#
# The image is a CoverPaintable, as upstream's is: a round placeholder until
# the art pipeline has found a picture of the artist.
class ArtistTile < Gtk::Box
  SIZE = Utils::ART_SIZES[:xsmall]

  def initialize
    super(:horizontal, 0)

    @coreartist = nil
    @clicked_listeners = []
    self.focusable = false
  end

  # Registers a listener for a click on the tile.
  def on_clicked(&block)
    @clicked_listeners << block
    block
  end

  def build
    tap do |box|
      box.append(cover_image)
      box.append(label)

      box.add_controller(click_gesture)
      click_gesture.signal_connect('pressed') do
        @clicked_listeners.dup.each(&:call)
      end
    end
  end

  def coreartist = @coreartist

  def coreartist=(coreartist)
    @coreartist = coreartist
    self.text = coreartist.artist.to_s
    cover_paintable.coreobject = coreartist
  end

  def text = label.label

  def text=(text)
    label.tap do |l|
      l.label = text
      l.tooltip_text = text
    end
  end

  def cover_paintable = @cover_paintable ||= CoverPaintable.new(self, SIZE, :artist)

  def cover_image
    @cover_image ||= Gtk::Image.new.tap do |image|
      image.paintable = cover_paintable
      image.set_size_request(SIZE.width, SIZE.height)
      image.pixel_size = SIZE.height
      image.halign = :center
      image.valign = :center
    end
  end

  def label
    @label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.ellipsize = :end
      label.halign = :start
      label.hexpand = false
      label.margin_top = 16
      label.margin_bottom = 16
      label.margin_start = 10
      label.margin_end = 10
    end
  end

  def click_gesture = @click_gesture ||= Gtk::GestureClick.new
end
