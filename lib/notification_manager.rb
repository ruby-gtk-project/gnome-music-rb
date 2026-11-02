# frozen_string_literal: true

require 'adwaita'

# NotificationManager drives the loading indicator.
#
# Ported from upstream's gnomemusic/notificationmanager.py: a counter of
# in-flight loading operations which shows the window's progress bar while
# any are running and pulses it on a timeout.
#
# Upstream exposes this as an async context manager (`async with`); Ruby's
# equivalent is a block, so #loading wraps an operation and the push/pop pair
# stays available for callers that span more than one block.
class NotificationManager
  PULSE_INTERVAL = 100

  def initialize(window: nil)
    @window = window
    @pulse_id = 0
    @loading_counter = 0
  end

  # The window arrives after the manager, exactly as it does upstream, where
  # the manager watches the application's "window" property.
  def window=(window)
    @window = window
    if @loading_counter.positive?
      @window.loading_visible(true)
    end
  end

  def loading
    push_loading
    yield
  ensure
    pop_loading
  end

  def push_loading
    @loading_counter += 1

    if @pulse_id.zero? && @window
      @window.loading_visible(true)
      @pulse_id = GLib::Timeout.add(PULSE_INTERVAL) { @window.loading_pulse }
    end
  end

  def pop_loading
    @loading_counter -= 1

    if @loading_counter.zero? && !@pulse_id.zero?
      GLib::Source.remove(@pulse_id)
      @pulse_id = 0
      if @window
        @window.loading_visible(false)
      end
    end
  end
end
