# frozen_string_literal: true

require_relative "main"

# GnomeMusic is the gem's namespace. The port itself is written as top level
# classes under lib/, one per upstream source file, the way the pilot port
# (gnome-contacts-rb) is; this is the name the launcher in exe/ reaches for.
module GnomeMusic
  Application = ::App
end
