# frozen_string_literal: true

require 'adwaita'

# VolumeButton is the volume control in the player toolbar: a menu button
# whose popover holds a mute toggle and a slider.
#
# A direct port of upstream's gnomemusic/widgets/volumebutton.py and
# data/ui/VolumeButton.ui. The slider works in the cubic scale a volume
# control should use, while the player's volume is linear; the icon follows
# the cubic value, and dragging to zero mutes.
#
# Upstream converts between the two scales with
# GstAudio.stream_volume_convert_volume. There are no Gst bindings for Ruby,
# so the same conversion is done directly: GStreamer's cubic-to-linear
# mapping is the cube, and its inverse is the cube root.
class VolumeButton < Gtk::Box
  DEFAULT_UNMUTE_VOLUME = 0.25

  def initialize
    super(:horizontal, 0)

    @volume = 1.0
    @mute = false
    @updating = false
    @listeners = []
  end

  # Registers a listener for the volume or mute changing. The block is called
  # with :volume or :mute.
  def on_change(&block)
    @listeners << block
    block
  end

  def build
    tap do |box|
      box.append(menu_button)

      menu_button.popover = popover

      popover.tap do |pop|
        pop.child = popover_box

        popover_box.tap do |pbox|
          pbox.append(mute_button)
          pbox.append(scale)
        end
      end

      mute_button.signal_connect('toggled') { |button| self.mute = button.active? }
      adjustment.signal_connect('value-changed') { on_adjustment_changed }
    end.tap { update_icon }
  end

  def volume = @volume

  def volume=(value)
    if @volume != value
      @volume = value
      on_volume_changed
    end
  end

  def mute? = @mute

  def mute=(value)
    if @mute != value
      @mute = value
      on_mute_changed
    end
  end

  # Memoized widget methods

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.valign = :center
      button.direction = :up
      button.icon_name = 'audio-volume-high-symbolic'
      button.tooltip_text = 'Adjust Volume'
      button.add_css_class('circular')
    end
  end

  def popover
    @popover ||= Gtk::Popover.new.tap do |pop|
      pop.width_request = 250
    end
  end

  def popover_box = @popover_box ||= Gtk::Box.new(:horizontal, 0)

  def mute_button
    @mute_button ||= Gtk::ToggleButton.new.tap do |button|
      button.icon_name = 'audio-volume-muted-symbolic'
      button.tooltip_text = 'Mute/Unmute'
      button.add_css_class('circular')
      button.add_css_class('flat')
    end
  end

  def adjustment
    @adjustment ||= Gtk::Adjustment.new(
      1.0,
      0.0,
      1.0,
      0.01,
      0.1,
      0.0,
    )
  end

  def scale
    @scale ||= Gtk::Scale.new(:horizontal, adjustment).tap do |scale|
      scale.hexpand = true
      scale.draw_value = false
    end
  end

  private

    def cubic_to_linear(value) = value**3
    def linear_to_cubic(value) = value**(1.0 / 3)

    def announce(property)
      @listeners.dup.each { |listener| listener.call(property) }
    end

    def on_adjustment_changed
      unless @updating
        @volume = cubic_to_linear(adjustment.value)
        announce(:volume)

        if @volume.zero?
          self.mute = true
        elsif @mute
          self.mute = false
        end

        update_icon
      end
    end

    # Unmuting from a volume of zero gives the slider somewhere to sit, which
    # is what upstream does.
    def on_mute_changed
      if !@mute && @volume.zero?
        @volume = cubic_to_linear(DEFAULT_UNMUTE_VOLUME)
        announce(:volume)
      end

      mute_button.active = @mute
      announce(:mute)
      set_adjustment
      update_icon
    end

    def on_volume_changed
      if !@mute && @volume.zero?
        @mute = true
        mute_button.active = true
        announce(:mute)
      end

      announce(:volume)
      set_adjustment
    end

    def set_adjustment
      @updating = true
      if @mute
        adjustment.value = 0.0
      else
        adjustment.value = linear_to_cubic(@volume)
      end
      @updating = false
    end

    def update_icon
      linear_to_cubic(@volume).then do |volume_cubic|
        menu_button.icon_name = icon_for(volume_cubic)
      end
    end

    def icon_for(volume_cubic)
      if @mute
        'audio-volume-muted-symbolic'
      elsif volume_cubic < 0.3
        'audio-volume-low-symbolic'
      elsif volume_cubic < 0.7
        'audio-volume-medium-symbolic'
      else
        'audio-volume-high-symbolic'
      end
    end
end
