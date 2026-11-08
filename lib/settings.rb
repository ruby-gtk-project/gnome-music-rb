# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'fileutils'

# Settings holds the same keys as upstream's org.gnome.Music GSettings schema
# (data/org.gnome.Music.gschema.xml): the window geometry, the repeat mode
# and the suspend inhibitor.
#
# Upstream's `replaygain` key is deliberately not carried here: see
# preferences_dialog.rb's class comment for why this port has no control
# that would ever read it.
#
# Upstream uses GSettings, which needs a compiled schema installed into the
# system's glib-2.0/schemas directory. Requiring an install step to run the
# app from a checkout is worse than the alternative, so the same keys,
# defaults and semantics are backed by a small JSON file under
# XDG_CONFIG_HOME instead.
#
# The enum keys keep their nicks ("none", "song", "all", "shuffle" and
# "disabled", "album", "track"), so #enum and #enum= stand in for GSettings'
# get_enum/set_enum, and #on_change replaces the "changed::key" signal.
class Settings
  REPEAT_MODES = %w[none song all shuffle].freeze

  DEFAULTS = {
    'window-size'      => [768, 600],
    'window-maximized' => true,
    'repeat'           => 'none',
    'inhibit-suspend'  => false,
  }.freeze

  ENUMS = {
    'repeat' => REPEAT_MODES,
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
    @listeners = {}
  end

  def location = @path

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    key.to_s.then do |name|
      @values[name] = value
      write
      announce(name)
    end
    value
  end

  # The position of the current value in the key's enum, standing in for
  # GSettings#get_enum.
  def enum(key) = ENUMS.fetch(key.to_s).index(self[key]).to_i

  # Stores an enum key by position, standing in for GSettings#set_enum.
  def set_enum(key, position)
    ENUMS.fetch(key.to_s).then do |nicks|
      self[key] = nicks.fetch(position.clamp(0, nicks.length - 1))
    end
  end

  # Registers a listener for one key, standing in for the "changed::key"
  # signal. The block is called with the new value.
  def on_change(key, &block)
    (@listeners[key.to_s] ||= []) << block
    block
  end

  # Named accessors for every key, so callers do not repeat the strings.
  DEFAULTS.each_key do |key|
    method_name = key.tr('-', '_')
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
    if DEFAULTS[key] == false || DEFAULTS[key] == true
      define_method(:"#{method_name}?") { self[key] == true }
    end
  end

  private

    def announce(name)
      @listeners.fetch(name, []).dup.each { |listener| listener.call(@values[name]) }
    end

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'ruby-music',
        'settings.json',
      )
    end

    def read
      if File.exist?(@path)
        JSON.parse(File.read(@path))
      else
        {}
      end
    rescue JSON::ParserError => e
      warn "Error parsing #{@path}: #{e.message}"
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@values))
    end
end
