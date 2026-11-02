# frozen_string_literal: true

require 'adwaita'
require_relative 'playlist'

# PlaylistTile is one playlist in the playlists view sidebar.
#
# A direct port of upstream's gnomemusic/widgets/playlisttile.py and
# data/ui/PlaylistTile.ui: the playlist's icon and title, with the title
# doubling as the row's tooltip.
class PlaylistTile < Gtk::ListBoxRow
  attr_reader :playlist

  def initialize(playlist)
    super()

    @playlist = playlist
  end

  def build
    tap do |row|
      row.child = box

      box.tap do |b|
        b.append(icon)
        b.append(label)
      end

      icon.icon_name = @playlist.icon_name
      set_title(@playlist.title.to_s)

      @playlist.on_notify { |property| on_playlist_notify(property) }
    end
  end

  def box = @box ||= Gtk::Box.new(:horizontal, 0)

  def icon
    @icon ||= Gtk::Image.new.tap do |image|
      image.focusable = false
      image.icon_size = :normal
      image.valign = :center
      image.add_css_class('playlist-icon')
    end
  end

  def label
    @label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.ellipsize = :end
      label.halign = :start
      label.hexpand = false
      label.margin_top = 16
      label.margin_bottom = 16
      label.margin_start = 10
      label.margin_end = 10
    end
  end

  private

    def set_title(title)
      label.tap do |l|
        l.label = title
        l.tooltip_text = title
      end
    end

    def on_playlist_notify(property)
      if property == :title
        set_title(@playlist.title.to_s)
      end
    end
end
