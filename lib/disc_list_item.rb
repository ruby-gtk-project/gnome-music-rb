# frozen_string_literal: true

require 'adwaita'
require_relative 'disc_box'

# DiscListItem is one row of a GtkListView of an album's discs: a disc
# number label above a DiscBox of that disc's songs.
#
# Ported from upstream's data/ui/DiscListItem.ui, which is a GtkListItem
# template binding a label to the item's "disc_nr" property and a nested
# DiscBox's "model" to the item's "model" property. Upstream never wires this
# template into the resource bundle (it is absent from
# org.gnome.Music.gresource.xml) and there is no disclistitem.py: the real
# AlbumWidget binds its discs through a plain GtkListBox straight to DiscBox
# (see album_widget.rb), the same way this port does. This class is a
# faithful structural port of the unused template, kept so a GtkListView of
# discs can be built from it the same way AlbumTile backs the albums
# GridView's factory, via the .factory class method below.
class DiscListItem < Gtk::Box
  def initialize(application, corealbum)
    super(:vertical, 0)

    @application = application
    @corealbum = corealbum
    @coredisc = nil
    @disc_box = nil
    @song_activated_listeners = []
  end

  def build
    tap do |box|
      box.append(disc_number_label)
    end
  end

  # Registers a listener for a song being activated on this disc's DiscBox.
  # The block is called with the activated SongWidget.
  def on_song_activated(&block)
    @song_activated_listeners << block
    block
  end

  def coredisc = @coredisc

  def coredisc=(coredisc)
    @coredisc = coredisc

    disc_number_label.label = coredisc.disc_nr.to_s

    remove(@disc_box) if @disc_box
    @disc_box = DiscBox.new(@application, @corealbum, coredisc).build.tap do |box|
      box.on_song_activated { |song_widget| @song_activated_listeners.dup.each { |listener| listener.call(song_widget) } }
    end
    append(@disc_box)
  end

  # Builds the Gtk::SignalListItemFactory for a GtkListView bound to a
  # model of CoreDisc, the role upstream's DiscListItem.ui plays for a
  # GtkListItem factory: setup creates one DiscListItem per row, bind hands
  # it the row's CoreDisc.
  def self.factory(application, corealbum)
    Gtk::SignalListItemFactory.new.tap do |factory|
      factory.signal_connect('setup') { |_, list_item| list_item.child = new(application, corealbum).build }
      factory.signal_connect('bind') { |_, list_item| list_item.child.coredisc = list_item.item }
    end
  end

  def disc_number_label
    @disc_number_label ||= Gtk::Label.new.tap do |label|
      label.xalign = 0.0
      label.halign = :fill
      label.add_css_class('disc-label')
      label.add_css_class('heading')
    end
  end
end
