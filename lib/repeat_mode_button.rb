# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'

# RepeatModeButton is the repeat mode menu button in the player toolbar.
#
# A direct port of upstream's gnomemusic/widgets/repeatmodebutton.py and
# data/ui/RepeatModeButton.ui: a menu listing the four repeat modes, backed
# by a stateful action, with the button's icon following the mode in force.
class RepeatModeButton < Gtk::Box
  def initialize
    super(:horizontal, 0)

    @player = nil
  end

  def build
    tap do |box|
      box.append(menu_button)

      menu_button.menu_model = menu
      box.insert_action_group('repeatmenu', action_group)

      action_group.add_action(repeat_action)
      repeat_action.signal_connect('activate') do |_, state|
        on_repeat_menu_changed(state)
      end
    end
  end

  def player = @player

  # The player arrives after the widget, as it does upstream.
  def player=(player)
    @player = player
    @player.on_notify { |property| on_player_notify(property) }
    sync_to_player
  end

  # Memoized widget methods

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.direction = :up
      button.focusable = true
      button.receives_default = true
      button.icon_name = Utils::RepeatMode::NONE.icon
      button.add_css_class('circular')
      button.tooltip_text = 'Set Repeat Mode'
    end
  end

  def menu
    @menu ||= Gio::Menu.new.tap do |menu|
      Utils::RepeatMode::ALL_MODES.each do |mode|
        Gio::MenuItem.new.tap do |item|
          item.label = mode.label
          item.set_action_and_target_value(
            'repeatmenu.repeat',
            GLib::Variant.new(mode.value.to_s),
          )
          menu.append_item(item)
        end
      end
    end
  end

  def action_group = @action_group ||= Gio::SimpleActionGroup.new

  # The stateful form of the action: Gio::SimpleAction.new_stateful is not
  # bound in Ruby, but the three argument constructor is the same thing.
  def repeat_action
    @repeat_action ||= Gio::SimpleAction.new(
      'repeat',
      GLib::VariantType.new('s'),
      GLib::Variant.new('0'),
    )
  end

  private

    def on_player_notify(property)
      if property == :repeat_mode
        sync_to_player
      end
    end

    def sync_to_player
      @player.repeat_mode.then do |mode|
        menu_button.icon_name = mode.icon
        repeat_action.set_state(GLib::Variant.new(mode.value.to_s))
      end
    end

    def on_repeat_menu_changed(state)
      if @player
        repeat_action.set_state(state)
        @player.repeat_mode = Utils::RepeatMode.from_value(state.get_string.to_i)
      end
    end
end
