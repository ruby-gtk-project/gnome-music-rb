# frozen_string_literal: true

require 'adwaita'

require_relative 'utils'
require_relative 'music_logger'
require_relative 'settings'
require_relative 'search'
require_relative 'style'
require_relative 'notification_manager'
require_relative 'core_model'
require_relative 'local_search_playlists'
require_relative 'player'
require_relative 'about_dialog'
require_relative 'preferences_dialog'
require_relative 'shortcuts_dialog'
require_relative 'window'
require_relative 'gnome/music/rb/version'

# App is the application object.
#
# Ported from upstream's gnomemusic/application.py: it owns the logger, the
# settings, the search state, the list models, the playlists and the player,
# installs the thirteen application actions with the same accelerators, and
# opens the window.
#
# Upstream subclasses Adw.Application; the Ruby bindings cannot, so the
# application object is a Gtk::Application and only the window is Adwaita.
#
# Three of upstream's startup pieces are not here, because the components
# behind them are not ported yet: CoreGrilo, which is what fills the
# collection from Tracker, MPRIS, and the suspend inhibitor. Until the data
# source lands the collection is empty, which is the state upstream shows the
# welcome page for.
class App
  APP_ID = 'org.rubygtkproject.GnomeMusic'
  VERSION = Gnome::Music::Rb::VERSION
  ICON_DIR = File.expand_path('../data/icons', __dir__)
  HELP_URI = 'help:gnome-music'
  VOLUME_STEP = 0.1

  APP_ACTIONS = {
    'about'           => [],
    'help'            => ['F1'],
    'mute'            => ['<Ctrl>M'],
    'play_pause'      => ['<Ctrl>space', 'AudioPlay', 'AudioPause'],
    'preferences'     => ['<Ctrl>comma'],
    'quit'            => ['<Ctrl>Q'],
    'repeat_toggle'   => ['<Ctrl>R'],
    'shortcuts'       => ['<Ctrl>question'],
    'shuffle_toggle'  => ['<Ctrl>S'],
    'song_next'       => ['<Ctrl>N', 'AudioNext'],
    'song_previous'   => ['<Ctrl>B', 'AudioPrev'],
    'song_stop'       => ['AudioStop'],
    'volume_decrease' => ['<Ctrl>minus', '<Ctrl>KP_Subtract'],
    'volume_increase' => ['<Ctrl>plus', '<Ctrl>equal', '<Ctrl>KP_Add'],
  }.freeze

  attr_reader :log, :search, :settings, :coremodel, :notificationmanager, :playlists

  # app_id/flags are injectable so a test can register a throwaway
  # application rather than the session's real one, and present: false builds
  # the whole widget tree without ever mapping the window.
  def initialize(app_id: APP_ID, flags: :default_flags, present: true, settings: nil)
    @app_id = app_id
    @flags = flags
    @present = present
    @log = MusicLogger.new
    @settings = settings || Settings.new
    @search = Search.new
    @coremodel = CoreModel.new(@search)
    @notificationmanager = NotificationManager.new
    @playlists = LocalSearchPlaylists.new(collection: @coremodel)
    @window = nil
  end

  def app
    @app ||= begin
      Adwaita.init
      Gtk::Application.new(@app_id, @flags)
    end
  end

  def player = @player ||= Player.new(self)
  def window = @window

  def build
    app.tap do |a|
      a.signal_connect('startup') { on_startup }
      a.signal_connect('activate') { on_activate }
    end
  end

  def run = app.run([])

  private

    def on_startup
      Adwaita::StyleManager.default.color_scheme = :prefer_light
      Style.load
      register_icons
      set_actions
    end

    def on_activate
      if @window.nil?
        load_playlists
        @window = Window.new(self).build
        @notificationmanager.window = @window
      end

      if @present
        @window.present
      end
    end

    # The custom icons upstream ships in its GResource bundle live under
    # data/icons here, so the icon theme is told where to find them.
    def register_icons
      Gdk::Display.default.then do |display|
        if display && File.directory?(ICON_DIR)
          Gtk::IconTheme.get_for_display(display).add_search_path(ICON_DIR)
        end
      end
    end

    def load_playlists
      @playlists.load.then do |playlists|
        @coremodel.set_playlists(playlists)
        @coremodel.refresh_user_playlists
      end
    end

    def set_actions
      APP_ACTIONS.each do |name, accels|
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { send(:"action_#{name}") }
          app.add_action(action)
          unless accels.empty?
            app.set_accels_for_action("app.#{name}", accels)
          end
        end
      end
    end

    def action_about = AboutDialog.show(@app_id, VERSION, @window)

    def action_help
      Gtk.show_uri(@window, HELP_URI, Gdk::CURRENT_TIME)
    rescue StandardError, GLib::Error
      @log.message('Help handler not available.')
    end

    def action_mute
      player.mute = !player.mute?
    end

    def action_play_pause = player.play_pause

    def action_preferences
      PreferencesDialog.new(self).tap do |dialog|
        dialog.build
        dialog.present(@window)
      end
    end

    def action_quit = @window&.destroy

    def action_shortcuts
      ShortcutsDialog.new.tap do |dialog|
        dialog.build
        dialog.present(@window)
      end
    end

    # Upstream cycles song -> all -> none, and anything else to song.
    def action_repeat_toggle
      case player.repeat_mode
      when Utils::RepeatMode::SONG then player.repeat_mode = Utils::RepeatMode::ALL
      when Utils::RepeatMode::ALL then player.repeat_mode = Utils::RepeatMode::NONE
      else player.repeat_mode = Utils::RepeatMode::SONG
      end
    end

    def action_shuffle_toggle
      if player.repeat_mode == Utils::RepeatMode::SHUFFLE
        player.repeat_mode = Utils::RepeatMode::NONE
      else
        player.repeat_mode = Utils::RepeatMode::SHUFFLE
      end
    end

    def action_song_next = player.next
    def action_song_previous = player.previous
    def action_song_stop = player.stop

    # The volume steps work on the cubic scale a volume control should use,
    # as upstream's do; see volume_button.rb for the conversion.
    def action_volume_decrease
      unless player.mute?
        player.volume = linear([cubic(player.volume) - VOLUME_STEP, 0.0].max)
      end
    end

    def action_volume_increase
      if !player.mute? || player.volume.zero?
        player.volume = linear([cubic(player.volume) + VOLUME_STEP, 1.0].min)
      end

      if player.mute?
        player.mute = false
      end
    end

    def cubic(value) = value**(1.0 / 3)
    def linear(value) = value**3
end
