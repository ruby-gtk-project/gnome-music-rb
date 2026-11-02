# frozen_string_literal: true

require 'adwaita'

# MusicLogger is the application's logging facility.
#
# Ported from upstream's gnomemusic/musiclogger.py, which wraps the GLib
# logger and tags every record with the calling file, function and line:
#
#   * message is for user facing warnings, which ideally should be in the
#     application.
#   * warning is for logging non-fatal errors during execution.
#   * info is for extra runtime information.
#   * debug is for developer use.
#
# Upstream reaches GLib's structured logging through GLib.log_variant, which
# the Ruby bindings do not expose, so the records go to stderr in the same
# "(file, function, line) message" shape and debug output stays behind
# G_MESSAGES_DEBUG, as it is with GLib.
class MusicLogger
  DOMAIN = 'org.gnome.Music'

  LEVELS = {
    message: 'Message',
    warning: 'WARNING',
    info:    'INFO',
    debug:   'DEBUG',
  }.freeze

  # The levels upstream prefixes with the caller's location.
  LOCATED_LEVELS = %i[debug info warning].freeze

  def message(text) = log(text, :message)
  def warning(text) = log(text, :warning)
  def info(text) = log(text, :info)

  def debug(text)
    if debug_enabled?
      log(text, :debug)
    end
  end

  def debug_enabled?
    ENV.fetch('G_MESSAGES_DEBUG', '').then do |value|
      value == 'all' || value.split(/[\s,]+/).include?(DOMAIN)
    end
  end

  private

    def log(text, level)
      caller_locations(3, 1).first.then do |location|
        $stderr.puts("#{DOMAIN}-#{LEVELS.fetch(level)}: #{decorate(text, level, location)}")
      end
    end

    def decorate(text, level, location)
      if LOCATED_LEVELS.include?(level) && location
        "(#{File.basename(location.path)}, #{location.label}, #{location.lineno}) #{text}"
      else
        text.to_s
      end
    end
end
