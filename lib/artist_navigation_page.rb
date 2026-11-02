# frozen_string_literal: true

require 'adwaita'
require_relative 'artist_albums_widget'

# ArtistNavigationPage is the page the search results push for an artist.
#
# A direct port of upstream's gnomemusic/widgets/artistnavigationpage.py and
# data/ui/ArtistNavigationPage.ui: a header bar titled with the artist's
# name, over a scrolled ArtistAlbumsWidget.
class ArtistNavigationPage < Adwaita::NavigationPage
  def initialize(application, coreartist)
    # The toolbar view is built before the page because
    # Adwaita::NavigationPage takes its child as a constructor argument in the
    # Ruby bindings.
    @toolbar_view = Adwaita::ToolbarView.new
    super(@toolbar_view, coreartist.artist.to_s)

    @application = application
    @coreartist = coreartist
  end

  def build
    tap do
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scroller

        scroller.child = artist_albums.build
        artist_albums.coreartist = @coreartist
      end
    end
  end

  def toolbar_view = @toolbar_view
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def artist_albums = @artist_albums ||= ArtistAlbumsWidget.new(@application)

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.focusable = false
      window.hexpand = true
      window.vexpand = true
      window.hscrollbar_policy = :never
    end
  end
end
