# frozen_string_literal: true

# Config for development dependencies of this library
# i.e., not configured by this library
#
# SimpleCov & related config (must run BEFORE any other requires)
# NOTE: Gemfiles for non-coverage appraisals may not have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  if Kettle::Soup::Cover::DO_COV
    # Requiring simplecov loads the project-local `.simplecov`.
    require "simplecov"
    require "kettle/soup/cover/config"
    SimpleCov.start
  end
rescue LoadError => error
  # check the error message and re-raise when unexpected
  unless error.message.include?("kettle")
    raise error
  end
end

# External RSpec & related config
#
# The dev shell's own rspec (pkgs.rubyPackages_3_4.rspec in flake.nix) is a
# bare RSpec with no kettle-test alongside it, so requiring kettle-test
# unconditionally made this file — and therefore every spec — unloadable
# inside `nix develop`, which is exactly why the suite had never been run.
# Where kettle-test is available (the kettle-dev gemfiles this repo also
# ships), it still installs the harness helpers documented in
# spec/README.md; where it is not, the specs fall back to plain RSpec.
begin
  require "kettle/test/rspec"
rescue LoadError => error
  unless error.message.include?("kettle")
    raise error
  end
end

# This library
#
# The gemspec computes its version by `Kernel.load`ing this file directly
# rather than requiring it (see gnome-music-rb.gemspec), so there has never
# been a lib/gnome/music/rb.rb for a plain `require "gnome/music/rb"` to
# find — only lib/gnome/music/rb/version.rb. Requiring the version file by
# its real path is what the kettle-jem scaffold meant to do here.
require "gnome/music/rb/version"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
