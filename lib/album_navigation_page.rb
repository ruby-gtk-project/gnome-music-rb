# frozen_string_literal: true

require 'adwaita'
require_relative 'album_widget'

# AlbumNavigationPage is the page the albums grid pushes when an album is
# activated.
#
# A direct port of upstream's gnomemusic/widgets/albumnavigationpage.py and
# data/ui/AlbumNavigationPage.ui: a header bar whose title is the album and
# whose subtitle is the artist, over a scrolled AlbumWidget.
class AlbumNavigationPage < Adwaita::NavigationPage
  def initialize(application, corealbum)
    # The toolbar view is built before the page because
    # Adwaita::NavigationPage takes its child as a constructor argument in the
    # Ruby bindings.
    @toolbar_view = Adwaita::ToolbarView.new
    super(@toolbar_view, 'Albums')

    @application = application
    @corealbum = corealbum
  end

  def build
    tap do
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scroller

        header_bar.title_widget = page_title

        page_title.tap do |title|
          title.title = @corealbum.title.to_s
          title.subtitle = @corealbum.artist.to_s
        end

        scroller.child = album_widget.build
        album_widget.corealbum = @corealbum
      end
    end
  end

  def toolbar_view = @toolbar_view
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def page_title = @page_title ||= Adwaita::WindowTitle.new('', '')
  def album_widget = @album_widget ||= AlbumWidget.new(@application)

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.focusable = false
      window.hexpand = true
      window.vexpand = true
      window.hscrollbar_policy = :never
    end
  end
end
