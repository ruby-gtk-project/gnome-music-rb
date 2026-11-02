# frozen_string_literal: true

require 'adwaita'
require_relative 'cover_paintable'
require_relative 'disc_box'
require_relative 'playlist_dialog'
require_relative 'utils'

# AlbumWidget is the album detail view: the cover on the left, the album's
# details and controls beside it, and the songs below.
#
# Ported from upstream's gnomemusic/widgets/albumwidget.py and
# data/ui/AlbumWidget.ui, including the album menu's three actions — Play,
# Add to Favorite Songs and Add to Playlist… — and the "year, N minutes"
# release line. The disc headers above each disc are only shown when the
# album has more than one disc, as upstream does.
#
# The cover is a CoverPaintable, as upstream's is: it shows the placeholder
# icon until the art pipeline has found the album's artwork.
class AlbumWidget < Adwaita::Bin
  SIZE = Utils::ART_SIZES[:large]

  def initialize(application)
    super()

    @application = application
    @coremodel = application.coremodel
    @player = application.player
    @corealbum = nil
    @active_coreobject = nil
    @show_artist_label = true
  end

  def build
    tap do |bin|
      bin.child = clamp

      clamp.tap do |c|
        c.child = content_box

        content_box.tap do |box|
          box.append(album_info_box)
          box.append(disc_list_box)

          album_info_box.tap do |info|
            info.append(cover_image)
            info.append(album_details_box)

            album_details_box.tap do |details|
              details.append(title_label)
              details.append(artist_label)
              details.append(released_label)
              details.append(composer_label)
              details.append(buttons_box)

              buttons_box.tap do |buttons|
                buttons.append(play_button)
                buttons.append(menu_button)

                play_button.signal_connect('clicked') { play(nil, @corealbum) }
              end
            end
          end
        end
      end

      bin.insert_action_group('album', action_group)

      action_group.tap do |group|
        group.add_action(action('play') { play(nil, corealbum) })
        group.add_action(action('add_favorites') { add_favorites })
        group.add_action(action('add_playlist') { add_playlist })
      end
    end
  end

  def corealbum = @corealbum

  def corealbum=(corealbum)
    @corealbum = corealbum

    title_label.tap do |label|
      label.label = corealbum.title.to_s
      label.tooltip_text = corealbum.title.to_s
    end

    artist_label.tap do |label|
      label.label = corealbum.artist.to_s
      label.tooltip_text = corealbum.artist.to_s
    end

    cover_paintable.coreobject = corealbum
    set_composer_label
    update_release_info
    bind_discs
  end

  # The object the queue is filled from. In the albums view that is the album
  # itself; in the artists view it is the artist, so playing one album plays
  # the whole artist, which is what upstream does.
  def active_coreobject = @active_coreobject || @corealbum

  def active_coreobject=(coreobject)
    @active_coreobject = coreobject
  end

  def show_artist_label=(show)
    @show_artist_label = show
    artist_label.visible = show
  end

  # Memoized widget methods

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.margin_top = 48
      clamp.margin_bottom = 48
      clamp.maximum_size = 1000
    end
  end

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.halign = :fill
    end
  end

  def album_info_box
    @album_info_box ||= Gtk::Box.new(:horizontal, 32).tap do |box|
      box.halign = :fill
      box.hexpand = true
    end
  end

  def cover_paintable = @cover_paintable ||= CoverPaintable.new(self, SIZE, :album)

  def cover_image
    @cover_image ||= Gtk::Image.new.tap do |image|
      image.paintable = cover_paintable
      image.set_size_request(SIZE.width, SIZE.height)
      image.pixel_size = SIZE.height
      image.halign = :center
      image.valign = :center
    end
  end

  def album_details_box
    @album_details_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.halign = :center
      box.valign = :start
      box.margin_top = 18
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
      label.ellipsize = :middle
      label.margin_bottom = 18
      label.add_css_class('title-1')
    end
  end

  def artist_label
    @artist_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
      label.ellipsize = :middle
      label.margin_bottom = 12
      label.add_css_class('title-3')
    end
  end

  def released_label
    @released_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
      label.use_markup = true
      label.margin_bottom = 12
      label.add_css_class('dim-label')
    end
  end

  def composer_label
    @composer_label ||= Gtk::Label.new.tap do |label|
      label.focusable = false
      label.halign = :start
      label.ellipsize = :end
      label.margin_bottom = 12
      label.visible = false
      label.add_css_class('dim-label')
    end
  end

  def buttons_box
    @buttons_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.margin_top = 6
    end
  end

  def play_button
    @play_button ||= Gtk::Button.new.tap do |button|
      button.set_size_request(44, 44)
      button.icon_name = 'media-playback-start-symbolic'
      button.tooltip_text = 'Play'
      button.valign = :center
      button.add_css_class('circular')
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.set_size_request(44, 44)
      button.halign = :start
      button.valign = :center
      button.focus_on_click = false
      button.direction = :none
      button.icon_name = 'view-more-symbolic'
      button.menu_model = album_menu
      button.add_css_class('circular')
    end
  end

  def album_menu
    @album_menu ||= Gio::Menu.new.tap do |menu|
      menu.append('_Play', 'album.play')
      menu.append('Add to _Favorite Songs', 'album.add_favorites')
      menu.append('_Add to Playlist…', 'album.add_playlist')
    end
  end

  def disc_list_box
    @disc_list_box ||= Gtk::ListBox.new.tap do |list|
      list.focusable = false
      list.margin_top = 48
      list.selection_mode = :none
      list.add_css_class('background')
    end
  end

  def action_group = @action_group ||= Gio::SimpleActionGroup.new

  private

    def action(name, &block)
      Gio::SimpleAction.new(name).tap do |simple_action|
        simple_action.signal_connect('activate') { block.call }
      end
    end

    def bind_discs
      disc_list_box.tap do |list|
        list.set_header_func { |row, before| set_disc_header(row, before) }
        list.bind_model(@corealbum.model) { |coredisc| create_widget(coredisc) }
      end

      (@corealbum.model.n_items.zero?).then do |empty_album|
        play_button.sensitive = !empty_album
        menu_button.sensitive = !empty_album
      end
    end

    # Upstream hides the disc header for a single disc album.
    def set_disc_header(row, _before)
      Gtk::Label.new("Disc #{row.disc_nr}").tap do |header|
        header.xalign = 0.0
        header.halign = :fill
        header.visible = @corealbum.model.n_items > 1
        header.add_css_class('disc-label')
        header.add_css_class('heading')
        row.set_header(header)
      end
    end

    def create_widget(coredisc)
      DiscBox.new(@application, @corealbum, coredisc).build.tap do |disc_box|
        disc_box.on_song_activated do |song_widget|
          play(song_widget.coresong, active_coreobject)
        end
      end
    end

    def set_composer_label
      @corealbum.composer.to_s.then do |composer|
        unless composer.empty?
          composer_label.label = composer
          composer_label.tooltip_text = composer
        end

        composer_label.visible = !composer.empty?
      end
    end

    # Upstream rounds the album duration up to the next minute.
    def update_release_info
      ((@corealbum.duration / 60) + 1).then do |mins|
        pluralize_minutes(mins).then do |mins_text|
          if @corealbum.year.nil?
            released_label.label = mins_text
          else
            released_label.label = "#{@corealbum.year}, #{mins_text}"
          end
        end
      end
    end

    def pluralize_minutes(mins)
      if mins == 1
        '1 minute'
      else
        "#{mins} minutes"
      end
    end

    def play(coresong, coreobject)
      @coremodel.once_queue_loaded { @player.play(coresong) }
      @coremodel.active_core_object = coreobject
    end

    def add_favorites
      @corealbum.discs.each do |coredisc|
        coredisc.songs.each do |coresong|
          unless coresong.favorite?
            coresong.favorite = true
          end
        end
      end
    end

    def add_playlist
      @corealbum.discs.flat_map(&:songs).then do |selected_songs|
        PlaylistDialog.new(@application, selected_songs).tap do |dialog|
          dialog.build
          dialog.present(@application.window)
        end
      end
    end
end
