# frozen_string_literal: true

require 'adwaita'
require_relative 'gst_player'

# SmoothScale is the progress bar in the player toolbar.
#
# A direct port of upstream's gnomemusic/widgets/smoothscale.py: a Gtk::Scale
# whose timeout is recomputed from the song duration and the widget's width,
# so the indicator advances one pixel at a time rather than once a second.
# Seeks are smoothed too: dragging only seeks once the value has been stable
# for 100ms.
#
# The scale works in hundredths of a second (upstream's factor of 60), which
# is what gives a drag more positions than a song has seconds.
class SmoothScale < Gtk::Scale
  SCALE_FACTOR = 60
  SEEK_DELAY = 100
  MAX_TIMEOUT = 200

  def initialize
    super(:horizontal, nil)

    @player = nil
    @old_value = 0.0
    @seek_timeout = nil
    @timeout = nil

    self.draw_value = false
    add_css_class('smooth-scale')
  end

  def build
    tap do |scale|
      scale.add_controller(click_gesture)

      click_gesture.tap do |gesture|
        gesture.signal_connect('pressed') { on_button_pressed }
        gesture.signal_connect('released') { on_button_released }
      end

      scale.signal_connect('change-value') do |_, scroll_type, value|
        on_seek(scroll_type, value)
      end
    end
  end

  def player = @player

  # The player arrives after the widget, as it does upstream, where the
  # toolbar is built by Gtk::Builder and the player set afterwards.
  def player=(player)
    if !player.nil? && @player.nil?
      @player = player
      @player.on_notify { |property| on_player_notify(property) }
    end
  end

  def click_gesture = @click_gesture ||= Gtk::GestureClick.new

  private

    def on_player_notify(property)
      case property
      when :state then on_state_change
      when :duration then on_duration_changed
      end
    end

    def on_state_change
      @player.state.then do |state|
        if [Playback::STOPPED, Playback::LOADING].include?(state)
          self.value = 0
          self.sensitive = false
        else
          self.sensitive = true
        end

        if state == Playback::PLAYING
          update_position
        else
          remove_timeout
        end
      end
    end

    def on_duration_changed
      @player.duration.then do |duration|
        if duration != -1.0
          self.value = 0
          set_range(0.0, duration * SCALE_FACTOR)
          set_increments(300, 600)
        end
      end
    end

    # Only seek once the value has settled, so a drag does not stutter.
    def on_seek(scroll_type, value)
      if @seek_timeout
        GLib::Source.remove(@seek_timeout)
      end

      # Gtk::Range#change_value, which upstream chains to, is not bound in
      # Ruby; setting the value is what that default handler does.
      self.value = value

      if scroll_type == Gtk::ScrollType::JUMP
        @seek_timeout = GLib::Timeout.add(SEEK_DELAY) { on_seek_finish(value) }
      else
        # Scroll with keys, hence no smoothing.
        on_seek_finish(value)
        update_position
      end

      true
    end

    def on_seek_finish(value)
      @seek_timeout = nil

      if @old_value != value.round(round_digits)
        @player.set_position(value / SCALE_FACTOR)
        @old_value = value.round(round_digits)
      end

      false
    end

    def on_button_pressed
      remove_timeout
      @old_value = value
      false
    end

    def on_button_released
      if @seek_timeout
        GLib::Source.remove(@seek_timeout)
        on_seek_finish(value)
      end

      update_position
      false
    end

    # Sets the period of the position timeout small enough that the slider
    # moves one pixel at a time for the current song and scale width.
    def update_timeout
      @player.duration.abs.then do |duration|
        [width, 1].max.then do |pixels|
          [(1000 * duration / pixels).to_i, MAX_TIMEOUT].min.then do |period|
            if @timeout
              GLib::Source.remove(@timeout)
            end
            @timeout = GLib::Timeout.add([period, 1].max) { update_position }
          end
        end
      end
    end

    def remove_timeout
      if @timeout
        GLib::Source.remove(@timeout)
        @timeout = nil
      end
    end

    def update_position
      @player.get_position.then do |position|
        if position.positive?
          self.value = position * SCALE_FACTOR
        end
      end

      update_timeout
      false
    end
end
