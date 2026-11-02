# frozen_string_literal: true

require 'adwaita'

# Style is the application stylesheet.
#
# A direct port of upstream's data/style.css. Upstream ships the sheet in its
# GResource bundle and lets GTK load it from there; this port has no resource
# bundle, so the same rules are a string loaded into a Gtk::CssProvider at
# startup.
module Style
  CSS = <<~CSS
    /* AlbumCover/AlbumTile */
    .artist-label {
        font-size: smaller;
    }

    /* AlbumsView */

    #albums gridview {
        padding: 18px;
    }

    #albums gridview > child {
        margin: 9px;
        padding: 6px;
    }

    #albums gridview > child:hover,child:selected {
        background-color: var(--border-color);
    }

    /* SearchView FlowBox tiles */
    .tile:hover {
        background-color: var(--border-color);
    }

    /* Cover images in large tiles in AlbumsView and SearchView */
    .tile-image {
        margin: 6px;
    }

    .playlist-icon {
        padding: 10px;
        border-radius: 50%;
        background-color: var(--border-color);
    }

    .disc-label {
        padding: 12px 0;
    }

    /* PlayerToolbar */

    .smooth-scale {
        padding-top: 0px;
        padding-bottom: 0px;
    }

    .grey-image {
        color: color-mix(in srgb, currentColor 30%, transparent);
    }

    /* Used in TwoLineTip, AlbumWidget and ArtistAlbumsWidget */
    .bold-label {
      font-weight: bold;
    }

    .playlistdialog-row:selected {
        color: var(--window-fg-color);
        background-color: var(--border-color);
    }

    .playlistdialog-row:selected label {
        color: var(--view-fg-color);
    }

    /* SearchView */
    .search-header {
      font-weight: bold;
    }

    /* dnd icon for SongWidget */
    .drag-handle {
      color: color-mix(in srgb, currentColor 40%, transparent);
    }

    .drag-handle:backdrop {
      color: color-mix(in srgb, currentColor 40%, transparent);
    }

    /* SongWidget rows */
    .songwidget {
      padding: 12px;
    }

    /* Starring */
    button.star:hover {
      opacity: 1;
    }

    @keyframes rotate_star {
      from { -gtk-icon-transform: rotate(-72deg); }
      to {}
    }
    @keyframes rotate_unstar {
      from { -gtk-icon-transform: rotate(72deg); }
      to {}
    }

    button.star.interacted.starred image {
      animation: rotate_star 0.4s ease;
    }
    button.star.interacted:not(.starred) image {
      animation: rotate_unstar 0.4s ease;
    }
  CSS

  # Installs the stylesheet on the default display, at the application
  # priority GTK reserves for an app's own sheet.
  def self.load
    Gdk::Display.default.then do |display|
      if display
        Gtk::StyleContext.add_provider_for_display(
          display,
          provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
    end
  end

  def self.provider
    @provider ||= Gtk::CssProvider.new.tap do |css|
      css.load_from_data(CSS)
    end
  end
end
