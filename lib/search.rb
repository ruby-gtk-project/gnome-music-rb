# frozen_string_literal: true

require 'adwaita'

# Search carries the application-wide search state.
#
# A direct port of upstream's gnomemusic/search.py: a tiny object holding
# whether search mode is active and whether the last search produced
# anything. The header bars, the window and the search view all watch it.
#
# Upstream's two GObject properties are plain accessors here, with listeners
# registered through Utils::Observable in place of bind_property.
class Search
  include Utils::Observable

  # States the search can have.
  #
  #   NONE:      no ongoing search
  #   RESULT:    search with result
  #   NO_RESULT: search without result
  NONE = 0
  RESULT = 1
  NO_RESULT = 2

  def initialize
    @search_mode_active = false
    @state = NONE
  end

  def search_mode_active? = @search_mode_active

  def search_mode_active=(active)
    if @search_mode_active != active
      @search_mode_active = active
      notify_property(:search_mode_active)
    end
  end

  def state = @state

  def state=(state)
    if @state != state
      @state = state
      notify_property(:state)
    end
  end
end
