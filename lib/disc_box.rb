# frozen_string_literal: true

require 'adwaita'
require_relative 'song_widget'
require_relative 'song_widget_menu'

# DiscBox is one disc of an album: a boxed list of its songs.
#
# A direct port of upstream's gnomemusic/widgets/discbox.py and
# data/ui/DiscBox.ui. The disc label above it is set by the album widget's
# list header, which is where upstream puts it too.
class DiscBox < Gtk::ListBoxRow
  attr_reader :disc_nr

  def initialize(application, corealbum, coredisc)
    super()

    @application = application
    @corealbum = corealbum
    @coredisc = coredisc
    @disc_nr = coredisc.disc_nr
    @song_activated_listeners = []

    self.focusable = false
    self.activatable = false
    self.selectable = false
  end

  # Registers a listener for a song being activated. The block is called with
  # the activated SongWidget.
  def on_song_activated(&block)
    @song_activated_listeners << block
    block
  end

  def build
    tap do |row|
      row.child = list_box

      list_box.tap do |list|
        list.bind_model(@coredisc.model) { |coresong| create_widget(coresong) }
        list.signal_connect('row-activated') do |_, song_widget|
          @song_activated_listeners.dup.each { |listener| listener.call(song_widget) }
        end
      end
    end
  end

  def list_box
    @list_box ||= Gtk::ListBox.new.tap do |list|
      list.focusable = false
      list.valign = :start
      list.selection_mode = :none
      list.add_css_class('boxed-list')
    end
  end

  private

    def create_widget(coresong)
      SongWidget.new(coresong).build.tap do |song_widget|
        song_widget.menu = SongWidgetMenu.new(@application, song_widget, @corealbum).build
      end
    end
end
