# frozen_string_literal: true

require 'adwaita'
require_relative 'album_cover'
require_relative 'album_navigation_page'

# AlbumsSearchNavigationPage lists every album a search found.
#
# A direct port of upstream's
# gnomemusic/widgets/albumssearchnavigationpage.py and
# data/ui/AlbumsSearchNavigationPage.ui: the page behind the search view's
# "View All" button for albums. Activating an album pushes its page.
class AlbumsSearchNavigationPage < Adwaita::NavigationPage
  def initialize(application, model)
    # The toolbar view is built before the page because
    # Adwaita::NavigationPage takes its child as a constructor argument in the
    # Ruby bindings.
    @toolbar_view = Adwaita::ToolbarView.new
    super(@toolbar_view, 'Albums')

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
          box.bind_model(@model) { |corealbum| AlbumCover.new(corealbum).build }
          box.signal_connect('child-activated') do |_, album_cover|
            on_album_activated(album_cover)
          end
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

    def on_album_activated(album_cover)
      @navigation_view.push(
        AlbumNavigationPage.new(@application, album_cover.corealbum).build,
      )
    end
end
