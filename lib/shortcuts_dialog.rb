# frozen_string_literal: true

require 'adwaita'

# ShortcutsDialog lists the keyboard shortcuts.
#
# A direct port of upstream's data/ui/shortcuts-dialog.ui: the same three
# sections — General, Playback and Navigation — with the same items. The
# items upstream states by action name are listed here by the accelerator
# that action is bound to, since the dialog is built in code rather than from
# a UI file.
class ShortcutsDialog < Adwaita::ShortcutsDialog
  SECTIONS = {
    'General'    => [
      ['Preferences', '<Primary>comma'],
      ['Search', '<Primary>F'],
      ['Help', 'F1'],
      ['Keyboard shortcuts', '<Primary>question'],
      ['Quit', '<Primary>Q'],
    ],
    'Playback'   => [
      ['Play/Pause', '<Ctrl>space'],
      ['Next song', '<Ctrl>N'],
      ['Previous song', '<Ctrl>B'],
      ['Toggle repeat', '<Ctrl>R'],
      ['Toggle shuffle', '<Ctrl>S'],
      ['Increase volume', '<Ctrl>plus <Ctrl>equal'],
      ['Decrease volume', '<Ctrl>minus'],
      ['Toggle mute', '<Ctrl>M'],
    ],
    'Navigation' => [
      ['Go to Albums', '<Alt>1'],
      ['Go to Artists', '<Alt>2'],
      ['Go to Playlists', '<Alt>3'],
      ['Go back', '<Alt>Left'],
    ],
  }.freeze

  def initialize
    super()

    self.title = 'Keyboard Shortcuts'
  end

  def build
    tap do |dialog|
      SECTIONS.each do |title, items|
        dialog.add(section(title, items))
      end
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |label, accelerator| section.add(item(label, accelerator)) }
      end
    end

    # Positional, not keyword, arguments — even though the error a
    # no-argument new raises advertises the signatures as
    # "title: utf8, accelerator: utf8".
    def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
end
