# frozen_string_literal: true

require 'adwaita'
require_relative 'playlist'
require_relative 'playlist_tile'
require_relative 'playlists_widget'

# PlaylistsView is the main view for playlists: the playlists in the sidebar
# and the selected one's songs beside them.
#
# A direct port of upstream's gnomemusic/views/playlistsview.py and
# data/ui/PlaylistsView.ui, including the separator the sidebar draws between
# the smart playlists and the user's own, and the "untouched list" rule that
# selects the first playlist until the user picks one.
class PlaylistsView < Adwaita::Bin
  NAME = 'playlists'
  TITLE = 'Playlists'
  ICON_NAME = 'view-list-symbolic'

  def initialize(application)
    super()

    @application = application
    @coremodel = application.coremodel
    @untouched_list = true
    @current_playlist_listeners = []
    self.name = NAME
  end

  def view_name = NAME
  def title = TITLE
  def icon_name = ICON_NAME

  # Registers a listener for the selected playlist changing.
  def on_current_playlist_changed(&block)
    @current_playlist_listeners << block
    block
  end

  def build
    tap do |bin|
      bin.child = split_view

      split_view.tap do |view|
        view.sidebar = sidebar_scroller
        view.content = playlist_page

        sidebar_scroller.child = sidebar

        sidebar.tap do |list|
          list.set_header_func { |row, before| sidebar_header_func(row, before) }
          list.bind_model(@coremodel.playlists_model) { |playlist| PlaylistTile.new(playlist).build }
          list.signal_connect('row-activated') { on_playlist_activated(false) }
        end

        playlist_page.child = playlists_widget.build
      end

      @coremodel.playlists_model.signal_connect('items-changed') do |_, position, removed, _added|
        on_playlists_model_changed(position, removed)
      end
    end.tap { on_playlists_model_changed(0, 0) }
  end

  def current_playlist = sidebar.selected_row&.playlist

  def rename_active? = playlists_widget.rename_active?

  # Memoized widget methods

  def split_view = @split_view ||= Adwaita::OverlaySplitView.new

  def sidebar_scroller
    @sidebar_scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.width_request = 220
    end
  end

  def sidebar
    @sidebar ||= Gtk::ListBox.new.tap do |list|
      list.selection_mode = :single
      list.add_css_class('navigation-sidebar')
    end
  end

  def playlist_page = @playlist_page ||= Adwaita::Bin.new
  def playlists_widget = @playlists_widget ||= PlaylistsWidget.new(@application, self)

  private

    # A separator between the smart playlists and the user's own.
    def sidebar_header_func(row, before)
      if before && before.playlist.smart? && !row.playlist.smart?
        row.set_header(separator)
      else
        row.set_header(nil)
      end
    end

    def separator
      Gtk::Separator.new(:horizontal).tap do |sep|
        sep.height_request = 2
        sep.margin_start = 16
        sep.margin_end = 16
      end
    end

    def on_playlists_model_changed(position, removed)
      if @coremodel.playlists_model.n_items.zero?
        @untouched_list = true
      elsif @untouched_list
        select_row(sidebar.get_row_at_index(0))
      elsif removed.positive?
        select_row(sidebar.get_row_at_index(position) || sidebar.get_row_at_index(position - 1))
      end
    end

    def select_row(row)
      if row
        sidebar.select_row(row)
        on_playlist_activated(true)
      end
    end

    def on_playlist_activated(untouched)
      unless untouched
        @untouched_list = false
      end

      @current_playlist_listeners.dup.each(&:call)
    end
end
