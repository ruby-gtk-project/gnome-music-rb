# frozen_string_literal: true

require 'adwaita'

# StarToggle is the button that marks a song as a favorite.
#
# A direct port of upstream's gnomemusic/widgets/startoggle.py: a toggle
# button carrying the star/non-star icon and its tooltip, with the "starred"
# class driving the spin animation data/style.css defines. The "interacted"
# class is added on the first click so the animation only runs for the user's
# own clicks, not for the initial state.
class StarToggle < Gtk::ToggleButton
  def initialize
    super

    add_css_class('star')
    add_css_class('flat')
    add_css_class('circular')
  end

  def build
    tap do |button|
      button.signal_connect('toggled') { update }
      button.signal_connect('clicked') { button.add_css_class('interacted') }
    end.tap { update }
  end

  private

    def update
      if active?
        starred
      else
        unstarred
      end
    end

    def starred
      self.icon_name = 'starred-symbolic'
      # TRANSLATORS: A verb, to unmark a song as favorite
      self.tooltip_text = 'Unstar'
      add_css_class('starred')
    end

    def unstarred
      self.icon_name = 'non-starred-symbolic'
      # TRANSLATORS: A verb, to mark a song as favorite
      self.tooltip_text = 'Star'
      remove_css_class('starred')
    end
end
