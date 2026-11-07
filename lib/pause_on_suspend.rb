# frozen_string_literal: true

require 'adwaita'
require_relative 'gst_player'
require_relative 'music_logger'

# PauseOnSuspend pauses playback before the system actually suspends.
#
# Ported from upstream's gnomemusic/pauseonsuspend.py: it opens a proxy to
# `org.freedesktop.login1.Manager`, takes a "sleep" delay inhibitor through
# `Inhibit` whenever the player starts playing, releases that lock when
# playback stops (but not merely while loading), and listens for logind's
# "PrepareForSleep" signal to pause the player and release the lock before
# the machine actually sleeps, re-arming the lock on wake if still playing.
#
# Upstream drives the proxy creation and the Inhibit call with asyncio
# coroutines; the Ruby bindings have no asyncio, so both are the async
# Gio::DBusProxy calls ruby-gnome exposes as callbacks, run on the same GLib
# main loop the rest of the app uses. `Gio::DBusProxy#call_with_unix_fd_list`
# hands its callback the raw (proxy, Gio::Task, user_data) triple rather than
# the finished value directly, so the lock-taking path calls
# `call_with_unix_fd_list_finish` itself to get the result and the fd list,
# the same two-step upstream's `await` does under the hood.
class PauseOnSuspend
  BUS_NAME = 'org.freedesktop.login1'
  OBJECT_PATH = '/org/freedesktop/login1'
  INTERFACE_NAME = 'org.freedesktop.login1.Manager'

  INHIBIT_ARGUMENTS = '("sleep", "GNOME Music", "GNOME Music is pausing", "delay")'
  INHIBIT_SIGNATURE = '(ssss)'

  def initialize(player, logger: nil)
    @player = player
    @log = logger || MusicLogger.new
    @suspend_proxy = nil
    @signal_id = nil
    @file_descriptor = -1
    @previous_state = @player.state

    @player.on_notify do |name|
      if name == :state
        on_player_state_changed
      end
    end

    connect_proxy
  end

  private

    def connect_proxy
      Gio::DBusProxy.new_for_bus(
        :system,
        [:do_not_load_properties],
        nil,
        BUS_NAME,
        OBJECT_PATH,
        INTERFACE_NAME,
      ) { |proxy| @suspend_proxy = proxy }
    rescue StandardError => e
      @log.warning("Error: Failed to contact logind daemon: #{e.message}")
    end

    def on_player_state_changed
      new_state = @player.state
      return_if_unchanged(new_state) do
        if new_state == Playback::PLAYING && @file_descriptor == -1
          take_lock
        end

        if @previous_state == Playback::PLAYING && new_state != Playback::LOADING
          release_lock
        end

        @previous_state = new_state
      end
    end

    # No `return` in house style, so the "same state, do nothing" guard is a
    # yield gate instead of upstream's early return.
    def return_if_unchanged(new_state)
      unless @previous_state == new_state
        yield
      end
    end

    def take_lock
      if @suspend_proxy
        inhibit_variant = GLib::Variant.parse(INHIBIT_ARGUMENTS, INHIBIT_SIGNATURE)

        @suspend_proxy.call_with_unix_fd_list(
          'Inhibit',
          inhibit_variant,
          [],
          -1,
          nil,
        ) do |source, task, _user_data|
          begin
            _result, fd_list = source.call_with_unix_fd_list_finish(task)
            @file_descriptor = fd_list.get(0)
            @signal_id = source.signal_connect('g-signal') do |*signal_args|
              on_prepare_for_sleep(*signal_args.last(2))
            end
          rescue StandardError => e
            @log.warning("Error: Failed to finish proxy call: #{e.message}")
          end
        end
      end
    end

    def release_lock
      if @suspend_proxy && @file_descriptor >= 0
        IO.for_fd(@file_descriptor).close
        @file_descriptor = -1
        @suspend_proxy.signal_handler_disconnect(@signal_id)
        @signal_id = nil
      end
    end

    def on_prepare_for_sleep(signal_name, parameters)
      if signal_name == 'PrepareForSleep'
        going_to_sleep, = parameters.value

        if going_to_sleep == true
          @player.pause
          release_lock
        else
          take_lock
        end
      end
    end
end
