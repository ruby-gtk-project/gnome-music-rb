# frozen_string_literal: true

require 'adwaita'
require_relative 'header_bar'

# StatusNavigationPage is the page shown when there is no music to show.
#
# Ported from upstream's gnomemusic/widgets/statusnavigationpage.py and
# data/ui/StatusNavigationPage.ui. It has four states:
#
#   EMPTY             no music was found at startup (the default)
#   SEARCH            a search found nothing
#   NO_TRACKER        the indexer is unavailable
#   TRACKER_OUTDATED  the indexer is too old
#
# The empty state shows the welcome artwork, a title and a link to the user's
# Music folder; the others are an Adwaita status page. Upstream reads the
# artwork out of its GResource bundle, which this port does not have, so the
# same SVG is shipped under data/icons and loaded from there.
class StatusNavigationPage < Adwaita::NavigationPage
  EMPTY = 0
  SEARCH = 1
  NO_TRACKER = 2
  TRACKER_OUTDATED = 3

  WELCOME_ART = File.expand_path('../data/icons/welcome-music.svg', __dir__)

  def initialize(application)
    # The toolbar view is built before the page because
    # Adwaita::NavigationPage takes its child as a constructor argument in the
    # Ruby bindings.
    @toolbar_view = Adwaita::ToolbarView.new
    super(@toolbar_view, 'Music')

    @application = application
    @state = EMPTY
    self.tag = 'status'
  end

  def build
    tap do
      toolbar_view.tap do |view|
        view.top_bar_style = :raised
        view.add_top_bar(header_bar.build)
        view.content = status_page

        status_page.child = initial_state

        initial_state.tap do |clamp|
          clamp.child = initial_box

          initial_box.tap do |box|
            box.append(welcome_picture)
            box.append(title_label)
            box.append(description_label)
          end
        end
      end

      header_bar.state = HeaderBar::EMPTY
    end.tap { self.state = EMPTY }
  end

  def state = @state

  def state=(value)
    @state = value

    adw_clamp.visible = true
    initial_state.visible = false

    case value
    when EMPTY then set_empty_state
    when SEARCH then set_search_state
    when NO_TRACKER then set_no_tracker_state
    when TRACKER_OUTDATED then set_tracker_outdated_state
    end

    header_bar.state = HeaderBar::EMPTY
  end

  # Memoized widget methods

  def toolbar_view = @toolbar_view
  def header_bar = @header_bar ||= HeaderBar.new(@application)

  def status_page
    @status_page ||= Adwaita::StatusPage.new.tap do |page|
      page.hexpand = true
      page.vexpand = true
      page.icon_name = 'music-note-outline-symbolic'
    end
  end

  def initial_state
    @initial_state ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 620
      clamp.tightening_threshold = 500
    end
  end

  # AdwStatusPage's own built-in icon/title/description content, reached by
  # walking its internal widget tree exactly as upstream's __init__ does
  # ("Hack to get to AdwClamp, so it can be hidden for the initial state").
  # status_page.child= installs initial_state as a second, custom child
  # alongside this one rather than replacing it — status_page itself stays
  # visible the whole time, which is why #set_empty_state toggles this and
  # initial_state against each other instead of hiding status_page.
  def adw_clamp
    @adw_clamp ||= status_page.first_child.first_child.first_child.first_child
  end

  def initial_box
    @initial_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.valign = :start
    end
  end

  def welcome_picture
    @welcome_picture ||= Gtk::Picture.new.tap do |picture|
      picture.can_shrink = true
      picture.keep_aspect_ratio = true
      if File.exist?(WELCOME_ART)
        picture.file = Gio::File.new_for_path(WELCOME_ART)
      end
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new('Welcome to Music').tap do |label|
      label.justify = :center
      label.add_css_class('title-1')
    end
  end

  def description_label
    @description_label ||= Gtk::Label.new.tap do |label|
      label.justify = :center
      label.use_markup = true
      label.add_css_class('body')
    end
  end

  private

    # The text under the welcome artwork: a link to the user's Music folder,
    # or a note that the folder is not set.
    def content_text
      @content_text ||= music_folder_uri.then do |uri|
        if uri
          href = "<a href='#{uri}'>Music Folder</a>"
          # TRANSLATORS: This is a label to display a link to open a user's
          # music folder. {} will be replaced with the translated text
          # 'Music folder'
          "The contents of your #{href} will appear here."
        else
          'Your XDG Music directory is not set.'
        end
      end
    end

    def music_folder_uri
      GLib.get_user_special_dir(:music).then do |folder|
        if folder
          Gio::File.new_for_path(folder).uri
        end
      end
    end

    def set_empty_state
      adw_clamp.visible = false
      initial_state.visible = true
      description_label.label = content_text
    end

    def set_search_state
      status_page.tap do |page|
        page.title = 'No Music Found'
        page.description = 'Try a Different Search'
      end
    end

    def set_no_tracker_state
      status_page.tap do |page|
        page.title = 'GNOME Music could not connect to Tracker.'
        page.description = 'Your music files cannot be indexed without Tracker running.'
        page.icon_name = 'dialog-error-symbolic'
      end
    end

    def set_tracker_outdated_state
      status_page.tap do |page|
        page.title = 'Your system Tracker version seems outdated.'
        page.description = 'Music needs Tracker version 3.0.0 or higher.'
        page.icon_name = 'dialog-error-symbolic'
      end
    end
end
