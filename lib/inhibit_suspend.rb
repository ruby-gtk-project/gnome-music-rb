# frozen_string_literal: true

require 'adwaita'
require_relative 'gst_player'

# InhibitSuspend postpones automatic system suspend until the application has
# played all the songs in the queue.
#
# A direct port of upstream's gnomemusic/inhibitsuspend.py: while the player
# is playing or loading, and while the preference is on, the application holds
# a suspend inhibitor on its active window; when playback pauses or stops, or
# the preference is turned off, the inhibitor is handed back.
#
# Upstream watches the player's state through "notify::state" and the
# preference through GSettings' "changed::inhibit-suspend"; here the first is
# the port's own notify listener and the second the Settings object's change
# listener, which stand in for the GObject property bindings the Ruby
# bindings cannot install.
#
# One behaviour differs on purpose. Upstream re-runs its state handler when
# the preference changes, but that handler only ever takes the inhibitor when
# the preference is on and releases it on pause or stop, so switching the
# preference off in the middle of a song leaves the inhibitor held until
# playback stops. Here the release also covers the preference going off,
# which is what the preference says it does.
class InhibitSuspend
  REASON = 'Playing music'

  INHIBITING_STATES = [Playback::PLAYING, Playback::LOADING].freeze
  RELEASING_STATES = [Playback::PAUSED, Playback::STOPPED].freeze

  def initialize(application)
    @application = application
    @log = application.log
    @player = application.player
    @settings = application.settings
    @inhibit_cookie = 0
    @should_inhibit = @settings.inhibit_suspend?

    @player.on_notify do |name|
      if name == :state
        on_player_state_changed
      end
    end

    @settings.on_change('inhibit-suspend') { |value| on_inhibit_suspend_changed(value) }
  end

  def inhibiting? = @inhibit_cookie != 0

  # Applies the current player state, which is what the preference change
  # handler does too: turning the preference on while a song plays takes the
  # inhibitor at once, and turning it off releases it.
  def on_player_state_changed
    if INHIBITING_STATES.include?(@player.state)
      inhibit_suspend
    end

    if RELEASING_STATES.include?(@player.state) || !@should_inhibit
      uninhibit_suspend
    end
  end

  private

    def on_inhibit_suspend_changed(value)
      @should_inhibit = value == true
      on_player_state_changed
    end

    def inhibit_suspend
      if @inhibit_cookie.zero? && @should_inhibit
        @inhibit_cookie = @application.app.inhibit(
          @application.window,
          Gtk::ApplicationInhibitFlags::SUSPEND,
          REASON,
        )

        if @inhibit_cookie.zero?
          @log.warning('Unable to inhibit automatic system suspend')
        end
      end
    end

    def uninhibit_suspend
      unless @inhibit_cookie.zero?
        @application.app.uninhibit(@inhibit_cookie)
        @inhibit_cookie = 0
      end
    end
end
