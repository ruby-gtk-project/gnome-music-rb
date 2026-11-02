# frozen_string_literal: true

require 'adwaita'

# PreferencesDialog is the dialog behind the primary menu's Preferences item.
#
# A direct port of upstream's gnomemusic/widgets/preferencesdialog.py and
# data/ui/PreferencesDialog.ui: the repeat mode and ReplayGain combo rows
# under Player Settings, and the suspend inhibitor under Power Settings. Each
# row reads and writes the same settings key upstream binds it to.
class PreferencesDialog < Adwaita::PreferencesDialog
  REPEAT_MODES = %w[None Song All Shuffle].freeze
  REPLAY_GAIN_MODES = %w[Disabled Album Track].freeze

  def initialize(application)
    super()

    @settings = application.settings
    self.title = 'Preferences'
  end

  def build
    tap do |dialog|
      dialog.add(page)

      page.tap do |p|
        p.add(player_group)
        p.add(power_group)

        player_group.tap do |group|
          group.add(repeat_mode_row)
          group.add(replay_gain_row)

          repeat_mode_row.tap do |row|
            row.selected = @settings.enum('repeat')
            row.signal_connect('notify::selected') { @settings.set_enum('repeat', row.selected) }
          end

          replay_gain_row.tap do |row|
            row.selected = @settings.enum('replaygain')
            row.signal_connect('notify::selected') do
              @settings.set_enum('replaygain', row.selected)
            end
          end
        end

        power_group.tap do |group|
          group.add(inhibit_suspend_row)

          inhibit_suspend_row.tap do |row|
            row.active = @settings['inhibit-suspend']
            row.signal_connect('notify::active') { @settings['inhibit-suspend'] = row.active? }
          end
        end
      end
    end
  end

  # Memoized widget methods

  def page = @page ||= Adwaita::PreferencesPage.new

  def player_group
    @player_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = 'Player Settings'
    end
  end

  def repeat_mode_row
    @repeat_mode_row ||= Adwaita::ComboRow.new.tap do |row|
      row.title = 'Repeat Mode'
      row.model = Gtk::StringList.new(REPEAT_MODES)
    end
  end

  def replay_gain_row
    @replay_gain_row ||= Adwaita::ComboRow.new.tap do |row|
      row.title = 'ReplayGain'
      row.subtitle = 'Balance loudness between songs if ReplayGain metadata is found'
      row.model = Gtk::StringList.new(REPLAY_GAIN_MODES)
    end
  end

  def power_group
    @power_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = 'Power Settings'
    end
  end

  def inhibit_suspend_row
    @inhibit_suspend_row ||= Adwaita::SwitchRow.new.tap do |row|
      row.title = 'Inhibit Suspend'
      row.subtitle = 'Only while playing'
    end
  end
end
