# frozen_string_literal: true

require 'adwaita'
require_relative 'cover_paintable'
require_relative 'gst_player'
require_relative 'repeat_mode_button'
require_relative 'smooth_scale'
require_relative 'two_line_tip'
require_relative 'utils'
require_relative 'volume_button'

# PlayerToolbar is the bar across the bottom of the window while something is
# playing.
#
# A direct port of upstream's gnomemusic/widgets/playertoolbar.py and
# data/ui/PlayerToolbar.ui: the cover, title and artist on the left with a
# two-line tooltip, the previous/play/next buttons and the progress scale in
# the middle, and the repeat and volume buttons on the right. The bar reveals
# itself when there is something to play and hides again when the queue ends.
#
# The cover is a CoverPaintable, as upstream's is: it carries the playing
# song and fills in that song's album art once the art pipeline has it.
class PlayerToolbar < Gtk::ActionBar
  SIZE = Utils::ART_SIZES[:small]

  def initialize
    super

    @player = nil
    self.focusable = false
    self.revealed = false
  end

  def build
    tap do |bar|
      bar.pack_start(song_info_box)
      bar.set_center_widget(buttons_and_scale)
      bar.pack_end(menu_box)

      song_info_box.tap do |box|
        box.append(cover_image)
        box.append(now_playing_labels)

        now_playing_labels.tap do |labels|
          labels.append(title_label)
          labels.append(artist_label)
        end

        box.signal_connect('query-tooltip') do |_, _x, _y, _keyboard, tooltip|
          tooltip.set_custom(two_line_tip.build)
          true
        end
      end

      buttons_and_scale.tap do |box|
        box.append(buttons_box)
        box.append(scale_clamp)

        buttons_box.tap do |buttons|
          buttons.append(prev_button)
          buttons.append(play_button)
          buttons.append(next_button)

          prev_button.signal_connect('clicked') { @player.previous }
          play_button.signal_connect('clicked') { @player.play_pause }
          next_button.signal_connect('clicked') { @player.next }

          play_button.child = play_pause_image
        end

        scale_clamp.child = scale_and_timer

        scale_and_timer.tap do |box_inner|
          box_inner.append(progress_time_label)
          box_inner.append(progress_scale.build)
          box_inner.append(duration_label)

          progress_scale.signal_connect('value-changed') do |scale|
            on_progress_value_changed(scale)
          end
        end
      end

      menu_box.tap do |box|
        box.append(repeat_mode_button.build)
        box.append(volume_button.build)
      end
    end
  end

  def player = @player

  # The player arrives after the widget, as it does upstream, where the bar
  # comes out of Gtk::Builder and cannot be handed the player in its
  # constructor.
  def player=(player)
    if !player.nil? && @player.nil?
      @player = player
      progress_scale.player = player
      repeat_mode_button.player = player

      player.on_song_changed { update_view }
      player.on_notify { |property| on_player_notify(property) }

      volume_button.tap do |button|
        button.volume = player.volume
        button.mute = player.mute?
        button.on_change { |property| on_volume_button_change(property) }
      end
    end
  end

  # Memoized widget methods

  def song_info_box
    @song_info_box ||= Gtk::Box.new(:horizontal, 8).tap do |box|
      box.focusable = false
      box.halign = :center
      box.valign = :center
      box.has_tooltip = true
      box.margin_top = 6
      box.margin_bottom = 6
      box.margin_start = 6
      box.margin_end = 6
    end
  end

  def cover_paintable = @cover_paintable ||= CoverPaintable.new(self, SIZE, :album)

  def cover_image
    @cover_image ||= Gtk::Image.new.tap do |image|
      image.paintable = cover_paintable
      image.set_size_request(SIZE.width, SIZE.height)
      image.pixel_size = SIZE.height
    end
  end

  def now_playing_labels
    @now_playing_labels ||= Gtk::Box.new(:vertical, 3).tap do |box|
      box.focusable = false
      box.halign = :center
      box.valign = :center
      box.homogeneous = true
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
      label.ellipsize = :middle
      label.max_width_chars = 28
      label.add_css_class('bold-label')
    end
  end

  def artist_label
    @artist_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
      label.ellipsize = :middle
      label.max_width_chars = 28
    end
  end

  def buttons_and_scale
    @buttons_and_scale ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.focusable = false
      box.hexpand = true
      box.margin_top = 6
      box.margin_bottom = 6
      box.margin_start = 6
      box.margin_end = 6
    end
  end

  def buttons_box
    @buttons_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.focusable = false
      box.halign = :center
    end
  end

  def prev_button
    @prev_button ||= Gtk::Button.new.tap do |button|
      button.sensitive = false
      button.icon_name = 'media-skip-backward-symbolic'
      button.tooltip_text = 'Previous'
      button.valign = :center
      button.add_css_class('circular')
    end
  end

  def play_button
    @play_button ||= Gtk::Button.new.tap do |button|
      button.sensitive = false
      button.tooltip_text = 'Play'
      button.add_css_class('pill')
    end
  end

  def play_pause_image
    @play_pause_image ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'media-playback-start-symbolic'
      image.icon_size = :large
    end
  end

  def next_button
    @next_button ||= Gtk::Button.new.tap do |button|
      button.sensitive = false
      button.icon_name = 'media-skip-forward-symbolic'
      button.tooltip_text = 'Next'
      button.valign = :center
      button.add_css_class('circular')
    end
  end

  def scale_clamp
    @scale_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = 1000
    end
  end

  def scale_and_timer
    @scale_and_timer ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.focusable = false
      box.margin_top = 12
    end
  end

  def progress_time_label
    @progress_time_label ||= Gtk::Label.new('0∶00').tap do |label|
      label.focusable = false
      label.halign = :start
      label.valign = :center
      label.add_css_class('numeric')
    end
  end

  def progress_scale
    @progress_scale ||= SmoothScale.new.tap do |scale|
      scale.focusable = true
      scale.valign = :center
      scale.hexpand = true
    end
  end

  def duration_label
    @duration_label ||= Gtk::Label.new('0∶00').tap do |label|
      label.focusable = false
      label.halign = :start
      label.valign = :center
      label.add_css_class('numeric')
    end
  end

  def menu_box
    @menu_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.height_request = 34
      box.focusable = false
      box.halign = :end
      box.valign = :center
      box.margin_top = 6
      box.margin_bottom = 6
      box.margin_start = 6
      box.margin_end = 6
    end
  end

  def repeat_mode_button = @repeat_mode_button ||= RepeatModeButton.new
  def volume_button = @volume_button ||= VolumeButton.new
  def two_line_tip = @two_line_tip ||= TwoLineTip.new

  private

    def on_player_notify(property)
      case property
      when :state then sync_playing
      when :repeat_mode then sync_prev_next
      end
    end

    def on_volume_button_change(property)
      case property
      when :volume then @player.volume = volume_button.volume
      when :mute then @player.mute = volume_button.mute?
      end
    end

    def on_progress_value_changed(scale)
      (scale.value / SmoothScale::SCALE_FACTOR).to_i.then do |seconds|
        progress_time_label.label = Utils.seconds_to_string(seconds)
      end
    end

    def sync_playing
      if @player.state == Playback::STOPPED && !@player.has_next? && !@player.has_previous?
        self.revealed = false
      else
        self.revealed = true
        sync_play_button
      end
    end

    def sync_play_button
      if @player.state == Playback::PLAYING
        set_play_button('media-playback-pause-symbolic', 'Pause')
      else
        set_play_button('media-playback-start-symbolic', 'Play')
      end
    end

    def set_play_button(icon_name, tooltip)
      if play_pause_image.icon_name != icon_name
        play_pause_image.icon_name = icon_name
      end

      play_button.tooltip_text = tooltip
    end

    def sync_prev_next
      next_button.sensitive = @player.has_next?
      prev_button.sensitive = @player.has_previous?
    end

    # Updates every visual element on a song change.
    def update_view
      @player.current_song.then do |coresong|
        if coresong
          show_song(coresong)
        end
      end
    end

    def show_song(coresong)
      cover_paintable.coreobject = coresong
      duration_label.label = Utils.seconds_to_string(coresong.duration)
      progress_time_label.label = '0:00'
      play_button.sensitive = true
      sync_prev_next

      title_label.label = coresong.title.to_s
      artist_label.label = coresong.artist.to_s

      two_line_tip.tap do |tip|
        tip.title = coresong.title.to_s
        tip.subtitle = coresong.artist.to_s
      end
    end
end
