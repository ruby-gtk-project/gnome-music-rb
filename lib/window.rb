# frozen_string_literal: true

require 'adwaita'
require_relative 'albums_view'
require_relative 'artists_view'
require_relative 'header_bar'
require_relative 'player_toolbar'
require_relative 'playlists_view'
require_relative 'search_view'
require_relative 'status_navigation_page'
require_relative 'utils'
require_relative 'window_placement'

# Window is the main window.
#
# Ported from upstream's gnomemusic/window.py and data/ui/Window.ui: a
# navigation view holding the main page, whose toolbar carries the header bar
# over a view stack of the albums, artists and playlists views, with the
# loading progress bar overlaid and the player toolbar along the bottom.
#
# It also carries upstream's six window actions — navigate_back,
# search_bar_close, search_bar_open and the three view switches — with the
# same accelerators, and opens the search bar when the user starts typing a
# printable character in the main view. Upstream registers those accelerators
# on a shortcut controller; here they go on the application, because
# Gtk::ShortcutTrigger.parse_string has no Ruby binding.
#
# Upstream decides between the empty states by asking CoreGrilo whether
# Tracker is available or outdated. The Tracker wrapper is not ported yet, so
# the empty state is always the "no music found" one; the status page itself
# still carries the other two states.
class Window < Adwaita::ApplicationWindow
  MIN_WIDTH = 360
  MIN_HEIGHT = 294
  STARTUP_DELAY = 1000

  WINDOW_ACTIONS = {
    'navigate_back'    => ['<Alt>Left'],
    'search_bar_close' => ['Escape'],
    'search_bar_open'  => ['<Ctrl>F'],
    'view_albums'      => ['<Alt>1', '<Alt>KP_1'],
    'view_artists'     => ['<Alt>2', '<Alt>KP_2'],
    'view_playlists'   => ['<Alt>3', '<Alt>KP_3'],
  }.freeze

  attr_reader :views

  def initialize(application)
    super(application.app)

    @app = application
    @player = application.player
    @search = application.search
    @views = {}
    @search_view = nil
    @startup_timeout_id = 0

    self.title = 'Music'
    set_size_request(MIN_WIDTH, MIN_HEIGHT)
  end

  def build
    tap do |window|
      window.content = toolbar_view

      toolbar_view.tap do |view|
        view.top_bar_style = :raised
        view.bottom_bar_style = :raised
        view.content = toast_overlay
        view.add_bottom_bar(player_toolbar.build)

        toast_overlay.child = navigation_view

        navigation_view.add(main_navigation_page)

        main_toolbar_view.tap do |main_view|
          main_view.top_bar_style = :raised
          main_view.add_top_bar(header_bar.build)
          main_view.content = overlay

          overlay.tap do |o|
            o.child = stack
            o.add_overlay(loading_progress)
          end
        end
      end

      window.add_controller(key_controller)
      key_controller.signal_connect('key-pressed') do |_, keyval, _code, state|
        on_key_press(keyval, state)
      end

      WindowPlacement.new(window, @app.settings).build
      setup_view
      set_actions
    end
  end

  # --- Upstream's public surface ----------------------------------------

  def navigation_view
    @navigation_view ||= Adwaita::NavigationView.new
  end

  def headerbar = header_bar

  def active_view = stack.visible_child

  # Sets the player toolbar's visibility.
  def set_player_visible(visible)
    player_toolbar.revealed = visible
  end

  # Pulses the loading progress bar.
  def loading_pulse
    loading_progress.pulse

    true
  end

  # Sets the visibility of the loading progress bar.
  def loading_visible(show)
    loading_progress.visible = show
  end

  def add_toast(toast) = toast_overlay.add_toast(toast)

  # Memoized widget methods

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

  def main_navigation_page
    @main_navigation_page ||= Adwaita::NavigationPage.new(main_toolbar_view, 'Main View').tap do |page|
      page.tag = 'mainview'
    end
  end

  def main_toolbar_view = @main_toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= HeaderBar.new(@app)

  def overlay
    @overlay ||= Gtk::Overlay.new.tap do |overlay|
      overlay.vexpand = true
    end
  end

  def stack
    @stack ||= Adwaita::ViewStack.new.tap do |stack|
      stack.focusable = false
      stack.hhomogeneous = false
      stack.vhomogeneous = false
    end
  end

  def loading_progress
    @loading_progress ||= Gtk::ProgressBar.new.tap do |progress|
      progress.valign = :start
      progress.visible = false
      progress.add_css_class('osd')
    end
  end

  def player_toolbar = @player_toolbar ||= PlayerToolbar.new
  def status_navigation_page = @status_navigation_page ||= StatusNavigationPage.new(@app)
  def key_controller = @key_controller ||= Gtk::EventControllerKey.new

  private

    def setup_view
      header_bar.stack = stack
      player_toolbar.player = @player

      navigation_view.add(status_navigation_page.build)

      @search.on_notify { |property| on_search_notify(property) }
      @app.coremodel.on_notify { |property| on_coremodel_notify(property) }

      header_bar.state = HeaderBar::MAIN

      @startup_timeout_id = GLib::Timeout.add(STARTUP_DELAY) do
        @startup_timeout_id = 0
        on_songs_available
        false
      end
    end

    def on_search_notify(property)
      if property == :search_mode_active
        if @search.search_mode_active?
          navigation_view.replace_with_tags(['searchview'])
        else
          navigation_view.replace_with_tags(['mainview'])
        end
      end
    end

    def on_coremodel_notify(property)
      if property == :songs_available
        on_songs_available
      end
    end

    def on_songs_available
      unless @startup_timeout_id.zero?
        GLib::Source.remove(@startup_timeout_id)
        @startup_timeout_id = 0
      end

      if @app.coremodel.songs_available?
        switch_to_player_view
        navigation_view.replace_with_tags(['mainview'])
      else
        navigation_view.replace_with_tags(['status'])
        status_navigation_page.state = StatusNavigationPage::EMPTY
      end
    end

    # All views are created together, so if the albums view is already there,
    # the rest are too.
    def switch_to_player_view
      if @views.empty?
        header_bar.state = HeaderBar::MAIN
        create_views
        create_search_view
      end
    end

    def create_views
      [AlbumsView, ArtistsView, PlaylistsView].each do |klass|
        klass.new(@app).build.tap do |view|
          @views[view.view_name] = view
          stack.add_titled(view, view.view_name, view.title).icon_name = view.icon_name
        end
      end
    end

    def create_search_view
      SearchView.new(@app).build.tap do |view|
        @search_view = view
        navigation_view.add(view)
      end
    end

    # Upstream binds these through a Gtk::ShortcutController on the window.
    # Gtk::ShortcutTrigger.parse_string is not bound in Ruby, so the
    # accelerators are registered on the application, which reaches window
    # actions just the same.
    def set_actions
      WINDOW_ACTIONS.each do |name, accels|
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { send(:"action_#{name}") }
          add_action(action)
          @app.app.set_accels_for_action("win.#{name}", accels)
        end
      end
    end

    def action_navigate_back
      unless main_view_active?
        navigation_view.pop
      end
    end

    def action_search_bar_close
      if @search.search_mode_active?
        @search.search_mode_active = false
      end
    end

    def action_search_bar_open
      unless rename_active? || @search.search_mode_active?
        @search.search_mode_active = true
      end
    end

    def action_view_albums = switch_to_view(AlbumsView::NAME)
    def action_view_artists = switch_to_view(ArtistsView::NAME)
    def action_view_playlists = switch_to_view(PlaylistsView::NAME)

    def switch_to_view(view_name)
      if main_view_active? && @views.key?(view_name)
        stack.visible_child_name = view_name
      end
    end

    # True when the main page, the one with the view switcher, is showing.
    def main_view_active? = navigation_view.visible_page == main_navigation_page

    def rename_active? = @views[PlaylistsView::NAME]&.rename_active? || false

    # Typing a printable character in the main view opens the search bar and
    # starts the search with that character.
    def on_key_press(keyval, state)
      if open_search_for?(keyval, state)
        @search.search_mode_active = true
        @search_view.search_text = Gdk.keyval_to_unicode(keyval).chr(Encoding::UTF_8)
        true
      else
        false
      end
    end

    def open_search_for?(keyval, state)
      !@search.search_mode_active? &&
        !@search_view.nil? &&
        main_view_active? &&
        keyval != Gdk::Keyval::KEY_space &&
        printable?(keyval) &&
        plain_modifiers?(state) &&
        !rename_active?
    end

    def printable?(keyval)
      Gdk.keyval_to_unicode(keyval).then do |unicode|
        unicode.positive? && !unicode.chr(Encoding::UTF_8).match?(/[[:space:][:cntrl:]]/)
      end
    end

    def plain_modifiers?(state)
      (state & Gtk.accelerator_get_default_mod_mask).then do |modifiers|
        modifiers.zero? || modifiers == Gdk::ModifierType::SHIFT_MASK
      end
    end
end
