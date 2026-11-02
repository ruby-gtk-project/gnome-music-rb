# frozen_string_literal: true

require 'adwaita'
require_relative 'album_widget'

# ArtistAlbumsWidget lists every album by one artist.
#
# A direct port of upstream's gnomemusic/widgets/artistalbumswidget.py and
# data/ui/ArtistAlbumsWidget.ui: a vertical list of AlbumWidgets, each one
# playing the whole artist rather than just its own album, and each without
# the artist label, since the page is already about that artist.
class ArtistAlbumsWidget < Gtk::Box
  def initialize(application)
    super(:vertical, 0)

    @application = application
    @coreartist = nil
  end

  def build
    tap do |box|
      box.append(clamp)
      clamp.child = list_box
    end
  end

  def coreartist = @coreartist

  def coreartist=(coreartist)
    unless @coreartist.equal?(coreartist)
      @coreartist = coreartist
      update_model
    end
  end

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 1000
      clamp.orientation = :horizontal
    end
  end

  def list_box
    @list_box ||= Gtk::ListBox.new.tap do |list|
      list.add_css_class('background')
    end
  end

  private

    def update_model
      if @coreartist
        list_box.bind_model(@coreartist.model) { |corealbum| add_album(corealbum) }
      end
    end

    def add_album(corealbum)
      Gtk::ListBoxRow.new.tap do |row|
        row.selectable = false
        row.activatable = false
        row.focusable = false

        AlbumWidget.new(@application).build.tap do |widget|
          widget.corealbum = corealbum
          widget.active_coreobject = @coreartist
          widget.show_artist_label = false
          row.child = widget
        end
      end
    end
end
