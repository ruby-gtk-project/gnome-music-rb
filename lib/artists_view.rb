# frozen_string_literal: true

require 'adwaita'
require_relative 'artist_albums_widget'
require_relative 'artist_tile'

# ArtistsView is the main view of all available artists: a list of artists in
# the sidebar and every album by the selected one beside it.
#
# A direct port of upstream's gnomemusic/views/artistsview.py and
# data/ui/ArtistsView.ui, including the "untouched list" rule: while the user
# has not picked an artist, the first one is selected as soon as the list has
# anything in it.
class ArtistsView < Adwaita::Bin
  NAME = 'artists'
  TITLE = 'Artists'
  ICON_NAME = 'music-artist-symbolic'

  def initialize(application)
    super()

    @application = application
    @coremodel = application.coremodel
    @untouched_list = true
    self.name = NAME
  end

  def view_name = NAME
  def title = TITLE
  def icon_name = ICON_NAME

  def build
    tap do |bin|
      bin.child = split_view

      split_view.tap do |view|
        view.sidebar = sidebar_scroller
        view.content = artist_scroller

        sidebar_scroller.child = sidebar

        sidebar.tap do |list|
          list.model = selection_model
          list.factory = artist_item_factory
          list.signal_connect('activate') { |_, position| on_artist_activated(position) }
        end

        artist_scroller.child = artist_albums.build
      end

      selection_model.signal_connect_after('items-changed') { on_model_items_changed }
    end.tap { on_model_items_changed }
  end

  # Memoized widget methods

  def split_view = @split_view ||= Adwaita::OverlaySplitView.new
  def sidebar_scroller = @sidebar_scroller ||= Gtk::ScrolledWindow.new

  def sidebar
    @sidebar ||= Gtk::ListView.new.tap do |list|
      list.add_css_class('navigation-sidebar')
    end
  end

  def artist_scroller
    @artist_scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.hexpand = true
      window.vexpand = true
    end
  end

  def selection_model
    @selection_model ||= Gtk::SingleSelection.new(@coremodel.artists_model)
  end

  def artist_item_factory
    @artist_item_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
      factory.signal_connect('setup') { |_, list_item| setup_list_item(list_item) }
      factory.signal_connect('bind') { |_, list_item| list_item.child.coreartist = list_item.item }
    end
  end

  def artist_albums = @artist_albums ||= ArtistAlbumsWidget.new(@application)

  private

    def setup_list_item(list_item)
      ArtistTile.new.build.tap do |tile|
        list_item.child = tile
        tile.on_clicked { sidebar.signal_emit('activate', list_item.position) }
      end
    end

    def on_model_items_changed
      if selection_model.n_items.zero?
        @untouched_list = true
      elsif @untouched_list
        @untouched_list = false
        sidebar.signal_emit('activate', 0)
      end
    end

    def on_artist_activated(position)
      @untouched_list = false
      @coremodel.artists[position].then do |coreartist|
        if coreartist
          artist_albums.coreartist = coreartist
        end
      end
    end
end
