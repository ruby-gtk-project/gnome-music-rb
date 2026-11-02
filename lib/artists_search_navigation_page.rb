# frozen_string_literal: true

require 'adwaita'
require_relative 'artist_navigation_page'
require_relative 'artist_search_tile'

# ArtistsSearchNavigationPage lists every artist a search found.
#
# A direct port of upstream's
# gnomemusic/widgets/artistssearchnavigationpage.py and
# data/ui/ArtistsSearchNavigationPage.ui: the page behind the search view's
# "View All" button for artists. Activating an artist pushes its page.
class ArtistsSearchNavigationPage < Adwaita::NavigationPage
  def initialize(application, model)
    # The toolbar view is built before the page because
    # Adwaita::NavigationPage takes its child as a constructor argument in the
    # Ruby bindings.
    @toolbar_view = Adwaita::ToolbarView.new
    super(@toolbar_view, 'Artists')

    @application = application
    @model = model
    @navigation_view = application.window.navigation_view
  end

  def build
    tap do
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scroller

        scroller.child = clamp
        clamp.child = content_box
        content_box.append(flow_box)

        flow_box.tap do |box|
          box.bind_model(@model) { |coreartist| ArtistSearchTile.new(coreartist).build }
          box.signal_connect('child-activated') { |_, tile| on_artist_activated(tile) }
        end
      end
    end
  end

  def toolbar_view = @toolbar_view
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.focusable = false
      window.hexpand = true
      window.vexpand = true
      window.hscrollbar_policy = :never
    end
  end

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 1600
    end
  end

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.halign = :fill
      box.hexpand = true
      box.margin_top = 20
      box.margin_bottom = 20
      box.margin_start = 120
      box.margin_end = 120
    end
  end

  def flow_box
    @flow_box ||= Gtk::FlowBox.new.tap do |box|
      box.halign = :fill
      box.hexpand = true
      box.valign = :start
      box.homogeneous = true
      box.min_children_per_line = 1
      box.max_children_per_line = 6
      box.margin_top = 18
      box.margin_bottom = 18
      box.row_spacing = 12
      box.column_spacing = 6
      box.selection_mode = :none
    end
  end

  private

    def on_artist_activated(tile)
      @navigation_view.push(
        ArtistNavigationPage.new(@application, tile.coreartist).build,
      )
    end
end
