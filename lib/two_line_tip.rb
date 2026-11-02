# frozen_string_literal: true

require 'adwaita'

# TwoLineTip is a tooltip with two lines of text: a bolded title and a
# regular subtitle.
#
# Ported from upstream's gnomemusic/widgets/twolinetip.py and
# data/ui/TwoLineTip.ui. Upstream binds its title and subtitle properties to
# the two labels; here the setters write the labels directly, since the Ruby
# bindings have no properties to bind.
class TwoLineTip < Gtk::Box
  def initialize
    super(:vertical, 0)

    self.focusable = false
    self.vexpand = false
  end

  def build
    tap do |box|
      box.append(title_label)
      box.append(subtitle_label)
    end
  end

  def title = title_label.label

  def title=(title)
    title_label.label = title.to_s
  end

  def subtitle = subtitle_label.label

  def subtitle=(subtitle)
    subtitle_label.label = subtitle.to_s
  end

  def subtitle_visible=(visible)
    subtitle_label.visible = visible
  end

  def title_label
    @title_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
      label.add_css_class('bold-label')
    end
  end

  def subtitle_label
    @subtitle_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
    end
  end
end
