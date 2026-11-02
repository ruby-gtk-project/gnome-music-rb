# frozen_string_literal: true

require 'adwaita'
require_relative 'playlist_toast'

# PlaylistControls is the header above a playlist's songs: its name, the song
# count, the play button and the playlist menu.
#
# A direct port of upstream's gnomemusic/widgets/playlistcontrols.py and
# data/ui/PlaylistControls.ui. The three menu items are window actions —
# win.playlist_play, win.playlist_delete and win.playlist_rename — and the
# last two are disabled for the smart playlists, which cannot be renamed or
# deleted. Renaming swaps the name label for an entry in place, and Escape
# puts the label back.
class PlaylistControls < Gtk::Box
  def initialize
    super(:vertical, 0)

    @application = nil
    @playlist = nil
    self.focusable = false
    self.margin_top = 30
  end

  def build
    tap do |box|
      box.append(name_stack)
      box.append(songs_count_label)
      box.append(buttons_box)

      name_stack.tap do |stack|
        stack.add_named(name_label, 'name_label')
        stack.add_named(rename_box, 'renaming_dialog')

        rename_box.tap do |rbox|
          rbox.append(rename_entry)
          rbox.append(rename_done_button)

          rename_entry.tap do |entry|
            entry.add_controller(rename_controller)
            entry.signal_connect('activate') { on_playlist_renamed }
            entry.signal_connect('changed') { on_rename_entry_changed }
          end

          rename_controller.signal_connect('key-pressed') do |_, keyval, _code, _state|
            on_rename_entry_key_pressed(keyval)
          end

          rename_done_button.signal_connect('clicked') { on_playlist_renamed }
        end
      end

      buttons_box.tap do |buttons|
        buttons.append(play_button)
        buttons.append(menu_button)

        play_button.signal_connect('clicked') { play_action.activate }
        menu_button.menu_model = playlist_menu
      end
    end.tap { disable_rename_playlist }
  end

  def application = @application

  # The application arrives after the widget, as it does upstream, where the
  # controls come out of Gtk::Builder.
  def application=(application)
    if !application.nil? && @application.nil?
      @application = application
      @coremodel = application.coremodel
      @player = application.player
      @window = application.window

      @window.tap do |window|
        window.add_action(delete_action)
        window.add_action(play_action)
        window.add_action(rename_action)
      end

      delete_action.signal_connect('activate') { on_delete_action }
      rename_action.signal_connect('activate') { enable_rename_playlist }
    end
  end

  def playlist = @playlist

  def playlist=(new_playlist)
    @playlist = new_playlist
    disable_rename_playlist

    delete_action.enabled = !new_playlist.smart?
    rename_action.enabled = !new_playlist.smart?

    name_label.label = new_playlist.title.to_s
    @playlist.on_notify { |property| on_playlist_notify(property) }
    on_songs_count_changed
  end

  def rename_active? = name_stack.visible_child_name == 'renaming_dialog'

  # Memoized widget methods

  def name_stack = @name_stack ||= Gtk::Stack.new

  def name_label
    @name_label ||= Gtk::Label.new('Playlist Name').tap do |label|
      label.focusable = false
      label.hexpand = true
      label.xalign = 0
      label.ellipsize = :middle
      label.margin_bottom = 10
      label.add_css_class('title-1')
    end
  end

  def rename_box
    @rename_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.add_css_class('linked')
    end
  end

  def rename_entry
    @rename_entry ||= Gtk::Entry.new.tap do |entry|
      entry.focusable = true
      entry.receives_default = true
    end
  end

  def rename_controller = @rename_controller ||= Gtk::EventControllerKey.new

  def rename_done_button
    @rename_done_button ||= Gtk::Button.new.tap do |button|
      button.label = '_Done'
      button.use_underline = true
      button.focusable = true
      button.receives_default = true
      button.add_css_class('suggested-action')
    end
  end

  def songs_count_label
    @songs_count_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
      label.margin_bottom = 4
      label.add_css_class('body')
    end
  end

  def buttons_box
    @buttons_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.margin_top = 18
      box.margin_bottom = 8
    end
  end

  def play_button
    @play_button ||= Gtk::Button.new.tap do |button|
      button.set_size_request(44, 44)
      button.focusable = true
      button.receives_default = true
      button.icon_name = 'media-playback-start-symbolic'
      button.tooltip_text = 'Play'
      button.valign = :center
      button.add_css_class('circular')
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.set_size_request(44, 44)
      button.focusable = true
      button.receives_default = true
      button.halign = :start
      button.valign = :center
      button.focus_on_click = false
      button.direction = :none
      button.icon_name = 'view-more-symbolic'
      button.add_css_class('circular')
    end
  end

  def playlist_menu
    @playlist_menu ||= Gio::Menu.new.tap do |menu|
      menu.append('_Play', 'win.playlist_play')
      menu.append('_Delete', 'win.playlist_delete')
      menu.append('_Rename…', 'win.playlist_rename')
    end
  end

  def delete_action = @delete_action ||= Gio::SimpleAction.new('playlist_delete')
  def play_action = @play_action ||= Gio::SimpleAction.new('playlist_play')
  def rename_action = @rename_action ||= Gio::SimpleAction.new('playlist_rename')

  private

    # Deleting the playlist that is playing stops the player first, which is
    # what upstream does.
    def on_delete_action
      if @coremodel.active_core_object.equal?(@playlist)
        @player.stop
        @window.set_player_visible(false)
      end

      PlaylistToast.new(@application, @playlist).build
    end

    def on_rename_entry_changed
      rename_done_button.sensitive = rename_entry.text_length.positive?
    end

    def on_rename_entry_key_pressed(keyval)
      if keyval == Gdk::Keyval::KEY_Escape
        disable_rename_playlist
      end

      false
    end

    def on_playlist_renamed
      rename_entry.text.then do |new_name|
        unless new_name.empty?
          @playlist.title = new_name
          disable_rename_playlist
        end
      end
    end

    def on_playlist_notify(property)
      case property
      when :title then name_label.label = @playlist.title.to_s
      when :count then on_songs_count_changed
      end
    end

    def on_songs_count_changed
      @playlist.count.then do |count|
        songs_count_label.label = pluralize_songs(count)
        play_button.sensitive = count.positive?
        play_action.enabled = count.positive?
      end
    end

    def pluralize_songs(count)
      if count == 1
        '1 Song'
      else
        "#{count} Songs"
      end
    end

    def enable_rename_playlist
      name_stack.visible_child_name = 'renaming_dialog'
      rename_entry.text = @playlist.title.to_s
      rename_entry.grab_focus
    end

    def disable_rename_playlist
      name_stack.visible_child_name = 'name_label'
    end
end
