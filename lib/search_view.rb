# frozen_string_literal: true

require 'adwaita'
require_relative 'album_cover'
require_relative 'album_navigation_page'
require_relative 'albums_search_navigation_page'
require_relative 'artist_navigation_page'
require_relative 'artist_search_tile'
require_relative 'artists_search_navigation_page'
require_relative 'search'
require_relative 'search_header_bar'
require_relative 'song_widget'
require_relative 'song_widget_menu'
require_relative 'utils'

# SearchView shows what a search found, in three sections: artists, albums
# and songs.
#
# A direct port of upstream's gnomemusic/views/searchview.py and
# data/ui/SearchView.ui. Each section only appears when it has something in
# it, and each shows a "View All" button when there is more than fits — six
# artists and eight albums, recomputed from the window width. With nothing
# searched for the page explains the search bar; with nothing found it says
# so.
class SearchView < Adwaita::NavigationPage
  ALBUM_SLICE = 8
  ARTIST_SLICE = 6
  TILE_PADDING = 32

  def initialize(application)
    # The toolbar view is built before the page because
    # Adwaita::NavigationPage takes its child as a constructor argument in the
    # Ruby bindings.
    @toolbar_view = Adwaita::ToolbarView.new
    super(@toolbar_view, 'Search view')

    @application = application
    @coremodel = application.coremodel
    @player = application.player
    @search = application.search
    @window = application.window
    @navigation_view = @window.navigation_view
    @search_state = Search::NONE

    self.tag = 'searchview'
    add_css_class('view')
  end

  def build
    tap do
      toolbar_view.tap do |view|
        view.top_bar_style = :raised
        view.add_top_bar(search_header_bar.build)
        view.content = stack

        stack.tap do |s|
          s.add_named(results_scroller, 'main')
          s.add_named(status_page, 'status')
        end
      end

      build_results
      connect_models
    end.tap do
      set_empty_status_page
      stack.visible_child_name = 'status'
    end
  end

  def search_text = search_header_bar.search_text

  def search_text=(text)
    search_header_bar.search_text = text
  end

  def search_state = @search_state

  def search_state=(state)
    @search_state = state
    search_header_bar.search_state = state

    case state
    when Search::RESULT then stack.visible_child_name = 'main'
    when Search::NONE
      set_empty_status_page
      stack.visible_child_name = 'status'
    when Search::NO_RESULT
      set_no_result_status_page
      stack.visible_child_name = 'status'
    end
  end

  # Memoized widget methods

  def toolbar_view = @toolbar_view
  def search_header_bar = @search_header_bar ||= SearchHeaderBar.new(@application)
  def stack = @stack ||= Gtk::Stack.new
  def status_page = @status_page ||= Adwaita::StatusPage.new

  def results_scroller
    @results_scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.hexpand = true
      window.vexpand = true
    end
  end

  def results_clamp
    @results_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 1600
    end
  end

  def container
    @container ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.halign = :fill
      box.hexpand = true
      box.margin_top = 20
      box.margin_bottom = 20
      box.margin_start = 120
      box.margin_end = 120
    end
  end

  def artist_header = @artist_header ||= section_header
  def album_header = @album_header ||= section_header

  def artist_title_label = @artist_title_label ||= section_label('Artists')
  def album_title_label = @album_title_label ||= section_label('Albums')
  def songs_title_label = @songs_title_label ||= section_label('Songs')

  def view_all_artists = @view_all_artists ||= view_all_button
  def view_all_albums = @view_all_albums ||= view_all_button

  def artist_flow_box = @artist_flow_box ||= results_flow_box
  def album_flow_box = @album_flow_box ||= results_flow_box

  def songs_header
    @songs_header ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.halign = :fill
      box.hexpand = true
      box.homogeneous = true
    end
  end

  def songs_list_box
    @songs_list_box ||= Gtk::ListBox.new.tap do |list|
      list.margin_top = 20
      list.add_css_class('boxed-list')
    end
  end

  def album_slice
    @album_slice ||= Gtk::SliceListModel.new(@coremodel.albums_search, 0, ALBUM_SLICE)
  end

  def artist_slice
    @artist_slice ||= Gtk::SliceListModel.new(@coremodel.artists_search, 0, ARTIST_SLICE)
  end

  private

    def section_header
      Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :fill
        box.hexpand = true
        box.homogeneous = true
        box.visible = false
      end
    end

    def section_label(text)
      Gtk::Label.new(text).tap do |label|
        label.focusable = false
        label.halign = :start
        label.add_css_class('search-header')
      end
    end

    def view_all_button
      Gtk::Button.new.tap do |button|
        button.halign = :end
        button.child = Gtk::Box.new(:horizontal, 6).tap do |box|
          box.append(Gtk::Label.new('View All'))
          box.append(Gtk::Image.new.tap { |image| image.icon_name = 'go-next-symbolic' })
        end
      end
    end

    def results_flow_box
      Gtk::FlowBox.new.tap do |box|
        box.halign = :fill
        box.hexpand = true
        box.valign = :start
        box.homogeneous = true
        box.min_children_per_line = 1
        box.max_children_per_line = 6
        box.margin_top = 18
        box.margin_bottom = 18
        box.row_spacing = 12
        box.column_spacing = 6
        box.selection_mode = :none
        box.visible = false
      end
    end

    def build_results
      results_scroller.child = results_clamp
      results_clamp.child = container

      container.tap do |box|
        box.append(artist_header)
        box.append(artist_flow_box)
        box.append(album_header)
        box.append(album_flow_box)
        box.append(songs_header)
        box.append(songs_list_box)

        artist_header.tap do |header|
          header.append(artist_title_label)
          header.append(view_all_artists)
          view_all_artists.signal_connect('clicked') { on_all_artists_clicked }
        end

        album_header.tap do |header|
          header.append(album_title_label)
          header.append(view_all_albums)
          view_all_albums.signal_connect('clicked') { on_all_albums_clicked }
        end

        songs_header.append(songs_title_label)
      end
    end

    def connect_models
      songs_list_box.tap do |list|
        list.bind_model(@coremodel.songs_search) { |coresong| create_song_widget(coresong) }
        list.signal_connect('row-activated') { |_, song_widget| on_song_activated(song_widget) }
      end

      album_flow_box.tap do |box|
        box.bind_model(album_slice) { |corealbum| AlbumCover.new(corealbum).build }
        box.signal_connect('child-activated') { |_, cover| on_album_activated(cover) }
      end

      artist_flow_box.tap do |box|
        box.bind_model(artist_slice) { |coreartist| ArtistSearchTile.new(coreartist).build }
        box.signal_connect('child-activated') { |_, tile| on_artist_activated(tile) }
      end

      connect_model_signals
    end

    def connect_model_signals
      @coremodel.songs_search.signal_connect_after('items-changed') { on_songs_changed }
      album_slice.signal_connect_after('items-changed') { on_albums_changed }
      artist_slice.signal_connect_after('items-changed') { on_artists_changed }
      @window.signal_connect('notify::default-width') { on_window_width_change }
      @navigation_view.signal_connect('replaced') { on_navigation_view_replaced }
    end

    def create_song_widget(coresong)
      SongWidget.new(coresong, can_dnd: false, show_artist_and_album: true)
                .build
                .tap do |song_widget|
        song_widget.show_song_number = false
        song_widget.menu = SongWidgetMenu.new(@application, song_widget, coresong).build
      end
    end

    def on_songs_changed
      @coremodel.songs_search.n_items.positive?.then do |items_found|
        songs_header.visible = items_found
        songs_list_box.visible = items_found
        check_visibility
      end
    end

    def on_albums_changed
      album_slice.n_items.positive?.then do |items_found|
        album_header.visible = items_found
        album_flow_box.visible = items_found
        check_visibility
        view_all_albums.visible = @coremodel.albums_search.n_items > album_slice.n_items
      end
    end

    def on_artists_changed
      artist_slice.n_items.positive?.then do |items_found|
        artist_header.visible = items_found
        artist_flow_box.visible = items_found
        check_visibility
        view_all_artists.visible = @coremodel.artists_search.n_items > artist_slice.n_items
      end
    end

    def check_visibility
      if @search.search_mode_active?
        update_search_state
      end
    end

    def update_search_state
      items_found?.then do |items_found|
        if items_found
          self.search_state = Search::RESULT
        elsif !search_text.to_s.empty?
          self.search_state = Search::NO_RESULT
        end
      end
    end

    def items_found?
      @coremodel.songs_search.n_items.positive? ||
        @coremodel.artists_search.n_items.positive? ||
        @coremodel.albums_search.n_items.positive?
    end

    def set_empty_status_page
      status_page.tap do |page|
        page.title = 'No Search Started'
        page.description = 'Use the searchbar to start searching for albums, artists or songs'
      end
    end

    def set_no_result_status_page
      status_page.tap do |page|
        page.title = 'No Results Found'
        page.description = 'Try a different search'
      end
    end

    def on_navigation_view_replaced
      if @navigation_view.visible_page&.tag != tag
        self.search_state = Search::NONE
      end
    end

    # How many tiles fit across, which is what decides the size of the two
    # slices.
    def on_window_width_change
      album_flow_box.width.then do |width|
        [width / (ArtistSearchTile::SIZE.width + TILE_PADDING), 1].max.then do |items_per_row|
          album_slice.size = 2 * items_per_row
          artist_slice.size = items_per_row
        end
      end
    end

    def on_song_activated(song_widget)
      song_widget.coresong.then do |coresong|
        @coremodel.once_queue_loaded { @player.play(coresong) }
        @coremodel.active_core_object = coresong
      end

      true
    end

    def on_album_activated(album_cover)
      @navigation_view.push(
        AlbumNavigationPage.new(@application, album_cover.corealbum).build,
      )
    end

    def on_artist_activated(tile)
      @navigation_view.push(
        ArtistNavigationPage.new(@application, tile.coreartist).build,
      )
    end

    def on_all_artists_clicked
      @navigation_view.push(
        ArtistsSearchNavigationPage.new(@application, @coremodel.artists_search).build,
      )
    end

    def on_all_albums_clicked
      @navigation_view.push(
        AlbumsSearchNavigationPage.new(@application, @coremodel.albums_search).build,
      )
    end
end
