# frozen_string_literal: true

require 'adwaita'

# WindowPlacement restores and saves the main window placement.
#
# A direct port of upstream's gnomemusic/windowplacement.py: the size and
# maximized state are read from settings when the window is built and written
# back as they change, with the size writes coalesced behind a 500ms timeout
# so a drag-resize does not write on every frame. Success may vary depending
# on the underlying window manager.
class WindowPlacement
  STORE_DELAY = 500

  def initialize(window, settings)
    @window = window
    @settings = settings
    @update_timeout_id = 0
  end

  def build
    restore_window_state

    @window.tap do |win|
      win.signal_connect('notify::maximized') { on_maximized }
      win.signal_connect('notify::default-height') { on_size_change }
      win.signal_connect('notify::default-width') { on_size_change }
    end
  end

  private

    def restore_window_state
      @settings['window-size'].then do |size|
        if size.is_a?(Array) && size.length == 2
          @window.set_default_size(size[0].to_i, size[1].to_i)
        end
      end

      if @settings['window-maximized']
        @window.maximize
      end
    end

    def on_size_change
      if @update_timeout_id.zero?
        @update_timeout_id = GLib::Timeout.add(STORE_DELAY) { store_size }
      end
    end

    def store_size
      @settings['window-size'] = [@window.width, @window.height]
      GLib::Source.remove(@update_timeout_id)
      @update_timeout_id = 0

      false
    end

    def on_maximized
      @settings['window-maximized'] = @window.maximized?
    end
end
