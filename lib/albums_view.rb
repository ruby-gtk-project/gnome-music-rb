# frozen_string_literal: true

require 'adwaita'
require_relative 'album_navigation_page'
require_relative 'album_tile'

# AlbumsView is the grid of every album.
#
# A direct port of upstream's gnomemusic/views/albumsview.py and
# data/ui/AlbumsView.ui: a grid view of AlbumTiles, single click to activate,
# which pushes an AlbumNavigationPage for the album.
class AlbumsView < Adwaita::Bin
  NAME = 'albums'
  TITLE = 'Albums'
  ICON_NAME = 'media-optical-cd-audio-symbolic'

  def initialize(application)
    super()

    @application = application
    @navigation_view = application.window.navigation_view
    self.name = NAME
  end

  def view_name = NAME
  def title = TITLE
  def icon_name = ICON_NAME

  def build
    tap do |bin|
      bin.child = scroller

      scroller.child = grid_view

      grid_view.tap do |grid|
        grid.model = selection_model
        grid.factory = list_item_factory
        grid.signal_connect('activate') { |_, position| on_album_activated(position) }
      end
    end
  end

  def scroller = @scroller ||= Gtk::ScrolledWindow.new

  def grid_view
    @grid_view ||= Gtk::GridView.new.tap do |grid|
      grid.max_columns = 10
      grid.single_click_activate = true
    end
  end

  def selection_model
    @selection_model ||= Gtk::MultiSelection.new(@application.coremodel.albums_model)
  end

  def list_item_factory
    @list_item_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
      factory.signal_connect('setup') { |_, list_item| list_item.child = AlbumTile.new.build }
      factory.signal_connect('bind') { |_, list_item| list_item.child.corealbum = list_item.item }
    end
  end

  private

    def on_album_activated(position)
      @application.coremodel.albums[position].then do |corealbum|
        if corealbum
          @navigation_view.push(AlbumNavigationPage.new(@application, corealbum).build)
        end
      end
    end
end
