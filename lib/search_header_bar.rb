# frozen_string_literal: true

require 'adwaita'
require_relative 'search'

# SearchHeaderBar is the header bar of the search view.
#
# A direct port of upstream's gnomemusic/widgets/searchheaderbar.py and
# data/ui/SearchHeaderBar.ui: the search toggle on the left and a wide search
# entry as the title. The entry drives the search, carries the error style
# when a search finds nothing, and closes the search bar on Escape.
#
# Upstream hands the term to Grilo, which queries Tracker. The data source is
# not ported yet, so the term goes to CoreModel, which filters the collection
# in process.
#
# Upstream also gives the entry its own shortcut controller so Escape closes
# the search bar while the entry has the focus. Gtk::ShortcutTrigger has no
# parse_string binding in Ruby, so Escape is one of the window's own
# accelerators instead; see window.rb.
class SearchHeaderBar < Adwaita::Bin
  SEARCH_DELAY = 250
  ENTRY_WIDTH = 500

  def initialize(application)
    super()

    @application = application
    @coremodel = application.coremodel
    @search = application.search
    @search_state = Search::NONE
    @text_changed_listeners = []
  end

  # Registers a listener for the entry's text changing.
  def on_search_text_changed(&block)
    @text_changed_listeners << block
    block
  end

  def build
    tap do |bin|
      bin.child = header_bar

      header_bar.tap do |bar|
        bar.pack_start(search_button)
        bar.title_widget = entry

        search_button.signal_connect('toggled') do |button|
          @search.search_mode_active = button.active?
        end

        entry.signal_connect('search-changed') { on_search_entry_changed }
      end

      @search.on_notify { |property| on_search_notify(property) }
    end
  end

  def search_text = entry.text

  def search_text=(text)
    entry.tap do |search_entry|
      search_entry.text = text.to_s
      search_entry.position = search_entry.text.length
    end
  end

  def search_state = @search_state

  def search_state=(state)
    @search_state = state

    case state
    when Search::NO_RESULT then set_error_style(true)
    when Search::RESULT then set_error_style(false)
    when Search::NONE
      set_error_style(false)
      entry.text = ''
    end
  end

  # Memoized widget methods

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.vexpand = false
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

  def entry
    @entry ||= Gtk::SearchEntry.new.tap do |search_entry|
      search_entry.placeholder_text = 'Search songs, artists and albums'
      search_entry.halign = :center
      search_entry.width_request = ENTRY_WIDTH
      search_entry.search_delay = SEARCH_DELAY
    end
  end

  private

    def on_search_entry_changed
      entry.text.then do |term|
        @coremodel.search(term)
        @text_changed_listeners.dup.each { |listener| listener.call(term) }

        if term.empty?
          set_error_style(false)
          self.search_state = Search::NONE
        end
      end
    end

    def on_search_notify(property)
      if property == :search_mode_active
        search_button.active = @search.search_mode_active?
        if @search.search_mode_active?
          entry.grab_focus
        end
      end
    end

    # Adds or removes the error state on the search entry.
    def set_error_style(error)
      if error
        entry.add_css_class('error')
      else
        entry.remove_css_class('error')
      end
    end
end
