# frozen_string_literal: true

require 'adwaita'

# HeaderBar is the header bar of the application.
#
# A direct port of upstream's gnomemusic/widgets/headerbar.py and
# data/ui/HeaderBar.ui: the search toggle on the left, the primary menu on
# the right and the view switcher in the middle. The four states decide what
# shows:
#
#   MAIN    the view switcher and the menu
#   CHILD   neither
#   SEARCH  no search button
#   EMPTY   the menu, with search insensitive and the switcher hidden
class HeaderBar < Adwaita::Bin
  MAIN = 0
  CHILD = 1
  SEARCH = 2
  EMPTY = 3

  def initialize(application)
    super()

    @application = application
    @search = application.search
    @state = MAIN
  end

  def build
    tap do |bin|
      bin.child = header_bar

      header_bar.tap do |bar|
        bar.pack_start(search_button)
        bar.pack_end(menu_button)

        search_button.signal_connect('toggled') do |button|
          @search.search_mode_active = button.active?
        end
      end

      @search.on_notify { |property| on_search_notify(property) }
    end.tap { self.state = MAIN }
  end

  def stack = @stack

  def stack=(stack)
    @stack = stack
    stack_switcher.stack = stack
  end

  def state = @state

  # Sets the state of the header bar. This influences both its look and what
  # it can do.
  def state=(value)
    @state = value
    update

    search_button.visible = value != SEARCH

    if value == EMPTY
      search_button.sensitive = false
      stack_switcher.visible = false
    else
      search_button.sensitive = true
      stack_switcher.visible = true
    end
  end

  # Memoized widget methods

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.vexpand = false
    end
  end

  def stack_switcher
    @stack_switcher ||= Adwaita::ViewSwitcher.new.tap do |switcher|
      switcher.focusable = false
      switcher.halign = :center
      switcher.policy = :wide
    end
  end

  def search_button
    @search_button ||= Gtk::ToggleButton.new.tap do |button|
      button.valign = :center
      button.sensitive = true
      button.icon_name = 'edit-find-symbolic'
      button.tooltip_text = 'Search'
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.valign = :center
      button.sensitive = true
      button.icon_name = 'open-menu-symbolic'
      button.primary = true
      button.tooltip_text = 'Menu'
      button.menu_model = primary_menu
    end
  end

  # The same menu upstream builds in data/ui/HeaderBar.ui.
  def primary_menu
    @primary_menu ||= Gio::Menu.new.tap do |menu|
      menu.append('Preferences', 'app.preferences')
      menu.append('Keyboard Shortcuts', 'app.shortcuts')
      menu.append('Help', 'app.help')
      menu.append('About Music', 'app.about')
    end
  end

  private

    def update
      if @state == MAIN
        header_bar.title_widget = stack_switcher
      else
        header_bar.title_widget = nil
      end

      menu_button.visible = [MAIN, EMPTY].include?(@state)
    end

    def on_search_notify(property)
      if property == :search_mode_active
        search_button.active = @search.search_mode_active?
      end
    end
end
