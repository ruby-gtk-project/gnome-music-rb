# frozen_string_literal: true

require 'adwaita'
require_relative 'playlist'

# PlaylistDialogRow is one playlist in the "Add to Playlist" dialog.
#
# A direct port of upstream's gnomemusic/widgets/playlistdialogrow.py and
# data/ui/PlaylistDialogRow.ui: the playlist's title and a tick which shows
# only for the selected row.
class PlaylistDialogRow < Gtk::ListBoxRow
  attr_reader :playlist

  def initialize(playlist)
    super()

    @playlist = playlist
    add_css_class('playlistdialog-row')
  end

  def build
    tap do |row|
      row.child = box

      box.tap do |b|
        b.append(label)
        b.append(selection_icon)
      end

      label.label = @playlist.title.to_s
    end
  end

  def selected? = selection_icon.visible?

  def selected=(selected)
    selection_icon.visible = selected
  end

  def box = @box ||= Gtk::Box.new(:horizontal, 0)

  def label
    @label ||= Gtk::Label.new.tap do |label|
      label.ellipsize = :end
      label.margin_top = 8
      label.margin_bottom = 8
      label.margin_start = 8
      label.margin_end = 8
      label.xalign = 0.0
    end
  end

  def selection_icon
    @selection_icon ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'selection-mode-symbolic'
      image.visible = false
    end
  end
end
