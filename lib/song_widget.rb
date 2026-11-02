# frozen_string_literal: true

require 'adwaita'
require_relative 'core_song'
require_relative 'star_toggle'
require_relative 'utils'

# SongWidget is the single song row used in DiscBox, the playlists view and
# the search view.
#
# Ported from upstream's gnomemusic/widgets/songwidget.py and
# data/ui/SongWidget.ui. It contains, in order: a drag handle, the play
# indicator or the track number, the title, optionally the artist and album,
# the duration, the star toggle and the menu button.
#
# Upstream binds the row to its CoreSong with property bindings; the Ruby
# bindings have no properties to bind, so the row registers a listener on the
# song through Utils::Observable and refreshes the affected label itself.
class SongWidget < Gtk::ListBoxRow
  DND_MIME_TYPE = 'text/plain;charset=utf-8'
  DND_PREFIX = 'songwidget:'

  # The state of the row, upstream's SongWidget.State.
  PLAYED = 0
  PLAYING = 1
  UNPLAYED = 2

  attr_reader :coresong

  def initialize(coresong, can_dnd: false, show_artist_and_album: false)
    super()

    @coresong = coresong
    @can_dnd = can_dnd
    @show_artist_and_album = show_artist_and_album
    @state = UNPLAYED
    @show_song_number = true
    @drag_x = 0.0
    @drag_y = 0.0
    @moved_listeners = []

    self.selectable = false
    add_css_class('songwidget')
  end

  # Registers a listener for a drag-and-drop move. The block is called with
  # the position the row was dragged from.
  def on_widget_moved(&block)
    @moved_listeners << block
    block
  end

  def build
    tap do |row|
      row.child = box

      box.tap do |b|
        b.append(dnd_icon)
        b.append(number_box)
        b.append(title_box)
        b.append(artist_box)
        b.append(album_duration_box)
        b.append(star_toggle.build)
        b.append(menu_button)

        number_box.tap do |nb|
          nb.append(play_icon)
          nb.append(number_label)
        end

        title_box.tap { |tb| tb.append(title_label) }
        artist_box.tap { |ab| ab.append(artist_label) }

        album_duration_box.tap do |adb|
          adb.append(album_label)
          adb.append(duration_label)
        end

        star_toggle.signal_connect('toggled') do |toggle|
          @coresong.favorite = toggle.active?
        end
      end

      row.add_controller(drag_source)
      row.add_controller(drop_target)

      drag_source.tap do |source|
        source.signal_connect('prepare') { |_, x, y| on_drag_prepare(x, y) }
        source.signal_connect('drag-begin') { |_, drag| on_drag_begin(drag) }
      end

      drop_target.signal_connect('drop') do |_, value, _x, _y|
        on_drop(value)
      end

      @coresong.on_notify { |property| on_song_notify(property) }
    end.tap { refresh }
  end

  def show_song_number? = @show_song_number

  def show_song_number=(show)
    @show_song_number = show
    number_label.visible = show
  end

  def state = @state

  # Sets the state of the row. This drives the title's emphasis and whether
  # the play indicator shows.
  def state=(value)
    @state = value

    title_label.tap do |label|
      label.remove_css_class('dim-label')
      label.remove_css_class('bold-label')
    end
    play_icon.visible = false

    if @coresong.validation == CoreSong::FAILED
      show_failed
    else
      show_state(value)
    end
  end

  def song_number = number_label.label

  # Sets the track number label. Upstream shows nothing for track zero.
  def song_number=(new_nr)
    if new_nr.to_i.zero?
      number_label.label = ''
    else
      number_label.label = new_nr.to_s
    end
  end

  def menu = menu_button.popover

  # Sets the song menu. With no menu, the menu button is not displayed.
  def menu=(menu)
    menu_button.tap do |button|
      button.popover = menu
      button.visible = !menu.nil?
    end
  end

  # Memoized widget methods

  def box
    @box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.focusable = false
    end
  end

  def dnd_icon
    @dnd_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'list-drag-handle-symbolic'
      image.visible = @can_dnd
      image.add_css_class('drag-handle')
    end
  end

  def number_box
    @number_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.width_request = 48
      box.focusable = false
      box.homogeneous = true
    end
  end

  def play_icon
    @play_icon ||= Gtk::Image.new.tap do |image|
      image.focusable = false
      image.icon_name = Utils::SONG_STATE_ICONS[:playing]
      image.visible = false
    end
  end

  def number_label
    @number_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :end
      label.justify = :right
      label.add_css_class('dim-label')
    end
  end

  def title_box
    @title_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.focusable = false
      box.hexpand = true
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.xalign = 0
      label.halign = :start
      label.hexpand = true
      label.ellipsize = :end
      label.max_width_chars = 50
      label.justify = :fill
      label.margin_start = 9
    end
  end

  def artist_box
    @artist_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.focusable = false
      box.hexpand = true
      box.visible = @show_artist_and_album
    end
  end

  def artist_label
    @artist_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.xalign = 0
      label.halign = :start
      label.hexpand = true
      label.ellipsize = :end
      label.max_width_chars = 90
      label.justify = :fill
      label.margin_start = 9
    end
  end

  def album_duration_box
    @album_duration_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.focusable = false
      box.hexpand = true
    end
  end

  def album_label
    @album_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.xalign = 0
      label.halign = :start
      label.hexpand = true
      label.ellipsize = :end
      label.max_width_chars = 90
      label.justify = :fill
      label.visible = @show_artist_and_album
    end
  end

  def duration_label
    @duration_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :end
      label.hexpand = true
      label.single_line_mode = true
      label.add_css_class('bold-label')
    end
  end

  def star_toggle
    @star_toggle ||= StarToggle.new.tap do |toggle|
      toggle.valign = :center
      toggle.margin_start = 12
      toggle.margin_end = 12
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.visible = false
      button.focusable = true
      button.icon_name = 'view-more-symbolic'
      button.add_css_class('flat')
    end
  end

  # Upstream only arms the drag source for rows that may be reordered, which
  # is the playlists view.
  def drag_source
    @drag_source ||= Gtk::DragSource.new.tap do |source|
      source.actions = :move
      if @can_dnd
        source.propagation_phase = :capture
      else
        source.propagation_phase = :none
      end
    end
  end

  # Upstream hands the row itself to the drop target. The Ruby bindings have
  # no constructor for a content provider holding an arbitrary object, so the
  # payload is the row's position behind the prefix below, and anything else
  # dropped on the row is ignored.
  def drop_target
    @drop_target ||= Gtk::DropTarget.new(GLib::Type['gchararray'], :move).tap do |target|
      target.preload = true
    end
  end

  private

    def refresh
      title_label.tap do |label|
        label.label = @coresong.title.to_s
        label.tooltip_text = @coresong.title.to_s
      end

      self.song_number = @coresong.track_number
      duration_label.label = Utils.seconds_to_string(@coresong.duration)
      artist_label.label = @coresong.artist.to_s
      album_label.label = @coresong.album.to_s
      star_toggle.active = @coresong.favorite?
      self.state = @coresong.state || UNPLAYED
    end

    def on_song_notify(property)
      case property
      when :state then self.state = @coresong.state || UNPLAYED
      when :favorite then star_toggle.active = @coresong.favorite?
      when :validation then on_validation_changed
      when :updated then refresh
      end
    end

    def on_validation_changed
      if @coresong.validation == CoreSong::FAILED
        play_icon.icon_name = Utils::SONG_STATE_ICONS[:error]
        play_icon.visible = true
      else
        play_icon.icon_name = Utils::SONG_STATE_ICONS[:playing]
      end
    end

    def show_failed
      play_icon.visible = true
      title_label.add_css_class('dim-label')
    end

    def show_state(value)
      case value
      when PLAYED then title_label.add_css_class('dim-label')
      when PLAYING
        play_icon.visible = true
        title_label.add_css_class('bold-label')
      end
    end

    def on_drag_prepare(x, y)
      @drag_x = x
      @drag_y = y
      Gdk::ContentProvider.new(DND_MIME_TYPE, GLib::Bytes.new("#{DND_PREFIX}#{index}"))
    end

    # The drag icon is a one-row list box holding a copy of this row, which is
    # what gives the dragged song the same look as the list it came from.
    def on_drag_begin(drag)
      Gtk::ListBox.new.tap do |drag_widget|
        drag_widget.set_size_request(width, height)

        SongWidget.new(@coresong, can_dnd: false, show_artist_and_album: true).build.tap do |row|
          row.show_song_number = show_song_number?
          drag_widget.append(row)
          drag_widget.drag_highlight_row(row)
        end

        Gtk::DragIcon.get_for_drag(drag).child = drag_widget
      end

      drag.set_hotspot(@drag_x, @drag_y)
    end

    def on_drop(value)
      @drag_x = 0.0
      @drag_y = 0.0

      source_position(value).then do |position|
        if position.nil? || position == index
          false
        else
          @moved_listeners.dup.each { |listener| listener.call(position) }
          true
        end
      end
    end

    def source_position(value)
      value.to_s.then do |payload|
        if payload.start_with?(DND_PREFIX)
          payload.delete_prefix(DND_PREFIX).to_i
        end
      end
    end
end
