# frozen_string_literal: true

require 'adwaita'
require_relative 'texture_cache'
require_relative 'utils'

# CoverPaintable is an album or artist cover, or the placeholder shown until
# there is one.
#
# Ported from upstream's gnomemusic/coverpaintable.py: it paints the artwork
# scaled down along its longest axis and clipped to rounded corners — fully
# round for an artist — and, while there is no artwork, a flat background with
# the placeholder icon at a third of the cover's size over it. Which of the
# two it paints follows the core object's thumbnail, so a cover fills itself
# in as soon as the art pipeline has found the art.
#
# Two details differ from upstream. The widget's GdkPaintable implementation
# has to be registered before the interface is included, or the Ruby bindings
# leave the type without it; and the paintable does not implement
# GdkPaintable's get_flags, which upstream uses to declare its size static,
# because the bindings cannot marshal a flags return value out of a Ruby
# virtual function. Without the declaration GTK re-measures the cover after
# an invalidation, which costs a measure and changes nothing on screen.
class CoverPaintable < GLib::Object
  type_register

  include Gdk::Paintable

  # The fraction of the cover the placeholder icon takes up.
  ICON_SCALE = 1.0 / 3

  ARTIST_RADIUS = 90.0
  SMALL_RADIUS = 4.5
  DEFAULT_RADIUS = 9.0

  LIGHT_BACKGROUND = 'rgba(95%, 95%, 95%, 1)'
  DARK_BACKGROUND = 'rgba(30%, 30%, 30%, 1)'

  # icon_type is :album or :artist, upstream's DefaultIconType.
  def initialize(widget, art_size, icon_type)
    super()

    @widget = widget
    @art_size = art_size
    @icon_type = icon_type
    @coreobject = nil
    @texture = nil
    @thumbnail_listener = nil

    style_manager.signal_connect('notify::dark') { on_dark_changed }
    texture_cache.on_texture { |texture| on_texture(texture) }
  end

  def coreobject = @coreobject

  # Points the cover at a new album, artist or song. The art of the previous
  # one is dropped at once, so a recycled cover never shows the wrong cover
  # while the new one loads.
  def coreobject=(coreobject)
    unless coreobject.equal?(@coreobject)
      texture_cache.clear_pending_lookup_callback
      drop_texture
      disconnect_thumbnail

      @coreobject = coreobject
      @thumbnail_listener = coreobject.on_notify do |name|
        if name == :thumbnail
          on_thumbnail_changed
        end
      end

      on_thumbnail_changed
    end
  end

  def icon_type = @icon_type

  def icon_type=(value)
    @icon_type = value
    invalidate_contents
  end

  def art_size = @art_size

  def texture_cache = @texture_cache ||= TextureCache.new
  def style_manager = @style_manager ||= Adwaita::StyleManager.default

  def icon_theme
    @icon_theme ||= Gtk::IconTheme.get_for_display(@widget.display)
  end

  # GdkPaintable implementation. The bindings dispatch a virtual function to
  # the "virtual_do_" prefixed method of the same name.

  def virtual_do_snapshot(snapshot, width, height)
    if @texture
      snapshot_texture(
        snapshot,
        @texture,
        width,
        height,
      )
    else
      snapshot_fallback_icon(snapshot, width, height)
    end
  end

  def virtual_do_get_intrinsic_width = @art_size.width
  def virtual_do_get_intrinsic_height = @art_size.height

  private

    # The artwork is scaled down along whichever axis is the longer one, so a
    # cover that is not square keeps its aspect ratio and stays centred.
    def snapshot_texture(snapshot, texture, width, height)
      scaled_size(texture, width, height).then do |(drawn_width, drawn_height)|
        @widget.scale_factor.then do |scale_factor|
          snapshot.save
          snapshot.scale(1.0 / scale_factor, 1.0 / scale_factor)

          Graphene::Rect.new(
            (width - drawn_width) / 2,
            (height - drawn_height) / 2,
            drawn_width,
            drawn_height,
          ).scale(scale_factor, scale_factor).then do |rect|
            snapshot.push_rounded_clip(Gsk::RoundedRect.new.init_from_rect(rect, radius * scale_factor))
            snapshot.append_scaled_texture(texture, Gsk::ScalingFilter::TRILINEAR, rect)
          end

          snapshot.pop
          snapshot.restore
        end
      end
    end

    def scaled_size(texture, width, height)
      (texture.height.to_f / texture.width).then do |ratio|
        if ratio > 1
          [width / ratio, height]
        else
          [width, height * ratio]
        end
      end
    end

    def snapshot_fallback_icon(snapshot, width, height)
      snapshot.push_rounded_clip(
        Gsk::RoundedRect.new.init_from_rect(
          Graphene::Rect.new(
            0,
            0,
            width,
            height,
          ),
          radius,
        ),
      )
      snapshot.append_color(
        background_color,
        Graphene::Rect.new(
          0,
          0,
          width,
          height,
        ),
      )
      snapshot.translate(
        Graphene::Point.new(
          (width / 2) - (width * (ICON_SCALE / 2)),
          (height / 2) - (height * (ICON_SCALE / 2)),
        ),
      )
      snapshot.push_opacity(0.7)
      placeholder_icon(width).snapshot(snapshot, width * ICON_SCALE, height * ICON_SCALE)
      snapshot.pop
      snapshot.pop
    end

    def placeholder_icon(width)
      icon_theme.lookup_icon(
        Utils::DEFAULT_ICONS.fetch(@icon_type),
        (width * ICON_SCALE).to_i,
        scale: @widget.scale_factor,
      )
    end

    def background_color
      if style_manager.dark?
        Gdk::RGBA.parse(DARK_BACKGROUND)
      else
        Gdk::RGBA.parse(LIGHT_BACKGROUND)
      end
    end

    def radius
      if @icon_type == :artist
        ARTIST_RADIUS
      elsif @art_size == Utils::ART_SIZES[:small]
        SMALL_RADIUS
      else
        DEFAULT_RADIUS
      end
    end

    # Only the placeholder follows the colour scheme; artwork looks the same
    # either way.
    def on_dark_changed
      if @texture.nil?
        invalidate_contents
      end
    end

    def on_thumbnail_changed
      @coreobject.thumbnail.then do |uri|
        if uri == 'generic'
          drop_texture
        else
          texture_cache.lookup(uri)
        end
      end
    end

    def on_texture(texture)
      unless texture.equal?(@texture)
        @texture = texture
        invalidate_contents
      end
    end

    def drop_texture
      if @texture
        @texture = nil
        invalidate_contents
      end
    end

    def disconnect_thumbnail
      if @thumbnail_listener
        @coreobject&.off_notify(@thumbnail_listener)
        @thumbnail_listener = nil
      end
    end
end
