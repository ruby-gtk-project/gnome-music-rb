# frozen_string_literal: true

require 'adwaita'
require_relative 'playlist_dialog_row'

# PlaylistDialog adds songs to a playlist.
#
# Ported from upstream's gnomemusic/widgets/playlistdialog.py and
# data/ui/PlaylistDialog.ui. It has two faces: with user playlists it lists
# them and reveals the "New Playlist…" bar at the bottom; with none it shows
# the "Enter a name for your first playlist" page instead. Picking a playlist
# and pressing Add, or typing a new name and pressing Create, adds the songs
# and closes the dialog.
class PlaylistDialog < Adwaita::Dialog
  def initialize(application, selected_songs)
    super()

    @application = application
    @coremodel = application.coremodel
    @playlists = application.playlists
    @selected_songs = selected_songs
    @selected_playlist = nil

    self.width_request = 400
    self.height_request = 500
    self.focusable = false
    add_css_class('view')
  end

  def build
    tap do |dialog|
      dialog.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = stack
        view.add_bottom_bar(bottom_bar)

        header_bar.tap do |bar|
          bar.title_widget = title_label
          bar.pack_start(cancel_button)
          bar.pack_end(select_button)

          cancel_button.signal_connect('clicked') { dialog.force_close }
          select_button.signal_connect('clicked') { on_selection }
        end

        stack.tap do |s|
          s.add_named(empty_box, 'empty')
          s.add_named(normal_box, 'normal')

          empty_box.tap do |box|
            box.append(empty_image)
            box.append(empty_label)
            box.append(first_playlist_entry)
            box.append(first_playlist_button)

            first_playlist_entry.signal_connect('activate') { on_editing_done }
            first_playlist_entry.signal_connect('changed') { on_entry_changed }
            first_playlist_entry.add_controller(first_entry_focus)
            first_entry_focus.signal_connect('enter') { list_box.unselect_all }
          end

          normal_box.tap do |box|
            box.append(scroller)

            scroller.tap do |window|
              window.child = list_box

              list_box.tap do |list|
                list.bind_model(@coremodel.user_playlists_model) do |playlist|
                  PlaylistDialogRow.new(playlist).build
                end
                list.signal_connect('selected-rows-changed') { on_selected_rows_changed }
              end
            end
          end
        end

        bottom_bar.tap do |bar|
          bar.append(new_playlist_entry)
          bar.append(new_playlist_button)

          new_playlist_entry.signal_connect('activate') { on_editing_done }
          new_playlist_entry.signal_connect('changed') { on_entry_changed }
          new_playlist_entry.add_controller(new_entry_focus)
          new_entry_focus.signal_connect('enter') { list_box.unselect_all }
          new_playlist_button.signal_connect('clicked') { on_editing_done }
        end
      end
    end.tap { set_view }
  end

  # Memoized widget methods

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.focusable = false
      bar.show_end_title_buttons = false
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new('Add to Playlist').tap do |label|
      label.single_line_mode = true
      label.ellipsize = :end
      label.width_chars = 5
      label.add_css_class('title')
    end
  end

  def cancel_button
    @cancel_button ||= Gtk::Button.new.tap do |button|
      button.label = '_Cancel'
      button.use_underline = true
      button.focusable = false
    end
  end

  def select_button
    @select_button ||= Gtk::Button.new.tap do |button|
      button.label = '_Add'
      button.use_underline = true
      button.sensitive = false
      button.focusable = false
      button.add_css_class('suggested-action')
    end
  end

  def stack
    @stack ||= Gtk::Stack.new.tap do |stack|
      stack.focusable = false
      stack.hexpand = true
      stack.vexpand = true
      stack.transition_duration = 250
    end
  end

  def empty_box
    @empty_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.focusable = false
      box.valign = :fill
      box.vexpand = true
      box.margin_top = 18
      box.margin_bottom = 18
      box.margin_start = 18
      box.margin_end = 18
    end
  end

  def empty_image
    @empty_image ||= Gtk::Image.new.tap do |image|
      image.focusable = false
      image.valign = :center
      image.pixel_size = 100
      image.icon_name = 'music-note-outline-symbolic'
      image.margin_bottom = 16
      image.vexpand = true
      image.add_css_class('grey-image')
    end
  end

  def empty_label
    @empty_label ||= Gtk::Label.new('Enter a name for your first playlist').tap do |label|
      label.focusable = false
      label.valign = :end
    end
  end

  def first_playlist_entry
    @first_playlist_entry ||= Gtk::Entry.new.tap do |entry|
      entry.width_request = 300
      entry.halign = :center
      entry.margin_top = 18
      entry.margin_bottom = 16
      entry.margin_start = 18
      entry.margin_end = 18
    end
  end

  def first_playlist_button
    @first_playlist_button ||= Gtk::Button.new.tap do |button|
      button.label = 'C_reate'
      button.use_underline = true
      button.width_request = 120
      button.sensitive = false
      button.halign = :center
      button.valign = :center
      button.margin_top = 10
      button.margin_bottom = 20
    end
  end

  def normal_box
    @normal_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.focusable = false
    end
  end

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.vexpand = true
    end
  end

  def list_box
    @list_box ||= Gtk::ListBox.new.tap do |list|
      list.selection_mode = :single
      list.valign = :start
    end
  end

  def bottom_bar
    @bottom_bar ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.focusable = false
      box.margin_top = 6
      box.margin_bottom = 6
      box.margin_start = 6
      box.margin_end = 6
      box.add_css_class('linked')
    end
  end

  def new_playlist_entry
    @new_playlist_entry ||= Gtk::Entry.new.tap do |entry|
      entry.hexpand = true
      entry.placeholder_text = 'New Playlist…'
    end
  end

  def new_playlist_button
    @new_playlist_button ||= Gtk::Button.new.tap do |button|
      button.label = 'Add'
      button.sensitive = false
      button.add_css_class('suggested-action')
    end
  end

  def first_entry_focus = @first_entry_focus ||= Gtk::EventControllerFocus.new
  def new_entry_focus = @new_entry_focus ||= Gtk::EventControllerFocus.new

  private

    def user_playlists_available? = @coremodel.user_playlists_model.n_items.positive?

    def set_view
      if user_playlists_available?
        show_list_view
      else
        show_empty_view
      end
    end

    def show_list_view
      stack.visible_child_name = 'normal'
      @add_playlist_button = new_playlist_button
      @add_playlist_entry = new_playlist_entry
      toolbar_view.reveal_bottom_bars = true
    end

    def show_empty_view
      stack.visible_child_name = 'empty'
      @add_playlist_button = first_playlist_button
      @add_playlist_entry = first_playlist_entry
      toolbar_view.reveal_bottom_bars = false
    end

    def on_selection
      @selected_playlist&.add_songs(@selected_songs)
      force_close
    end

    def on_selected_rows_changed
      @add_playlist_entry.text = ''
      @add_playlist_button.sensitive = false

      list_box.selected_row.then do |selected_row|
        if selected_row
          @selected_playlist = selected_row.playlist
        end

        select_button.sensitive = !selected_row.nil?
        mark_rows(selected_row)
      end
    end

    def mark_rows(selected_row)
      (0...@coremodel.user_playlists_model.n_items).each do |index|
        list_box.get_row_at_index(index).then do |row|
          if row
            row.selected = (row == selected_row)
          end
        end
      end
    end

    def on_entry_changed
      @add_playlist_button.sensitive = !@add_playlist_entry.text.empty?
    end

    # Creating a playlist from the dialog adds the songs to it straight away,
    # as upstream does once Tracker has confirmed the new playlist.
    def on_editing_done
      @add_playlist_entry.text.then do |text|
        unless text.empty?
          create_and_add(text)
        end
      end
    end

    def create_and_add(title)
      @playlists.create(title).tap do |playlist|
        @coremodel.set_playlists(@playlists.playlists)
        @coremodel.refresh_user_playlists
        playlist.add_songs(@selected_songs)
        force_close
      end
    end
end
