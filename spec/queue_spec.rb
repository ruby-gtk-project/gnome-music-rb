# frozen_string_literal: true

require_relative '../lib/queue'
require_relative '../lib/core_model'
require_relative '../lib/search'
require_relative '../lib/music_logger'
# queue.rb reads SongWidget's playback-state constants (PLAYED/PLAYING/
# UNPLAYED) without requiring it itself — it only ever runs after main.rb
# has pulled song_widget.rb in for other reasons — so this spec requires it
# directly rather than relying on load order.
require_relative '../lib/song_widget'

RSpec.describe PlayQueue do
  let(:search) { Search.new }
  let(:coremodel) { CoreModel.new(search) }
  let(:log) { MusicLogger.new }
  let(:songs) do
    (1..3).map do |n|
      {
        id:     "song:#{n}",
        title:  "Song #{n}",
        artist: 'An Artist',
        album:  'An Album',
        url:    "file:///music/song#{n}.ogg",
      }
    end
  end

  before do
    coremodel.load(songs)
    # Fills coremodel.queue_model from the songs view, the same way
    # CoreModel#active_core_object= does for a real "play everything" queue.
    coremodel.active_core_object = nil
  end

  subject(:queue) { described_class.new(coremodel, log) }

  describe 'with a freshly started queue' do
    before { queue.set_song(nil) }

    it 'starts at the first song' do
      expect(queue.current_song.title).to eq('Song 1')
      expect(queue.position).to eq(0)
    end

    it 'has a next song but no previous song' do
      expect(queue.has_next?).to be(true)
      expect(queue.has_previous?).to be(false)
    end
  end

  describe '#next and #previous' do
    before { queue.set_song(nil) }

    it 'moves forward through the queue' do
      expect(queue.next).to be(true)

      expect(queue.current_song.title).to eq('Song 2')
      expect(queue.position).to eq(1)
    end

    it 'moves back to the previous song' do
      queue.next

      expect(queue.previous).to be(true)
      expect(queue.current_song.title).to eq('Song 1')
    end

    it 'has no next song at the end of the queue with repeat off' do
      queue.next
      queue.next

      expect(queue.has_next?).to be(false)
      expect(queue.next).to be(false)
    end
  end

  describe 'with repeat mode ALL' do
    before do
      queue.repeat_mode = Utils::RepeatMode::ALL
      queue.set_song(nil)
    end

    it 'always reports a next and a previous song' do
      expect(queue.has_next?).to be(true)
      expect(queue.has_previous?).to be(true)
    end

    it 'wraps from the last song back to the first' do
      queue.next
      queue.next

      expect(queue.current_song.title).to eq('Song 3')

      queue.next

      expect(queue.current_song.title).to eq('Song 1')
    end
  end

  describe 'with repeat mode SONG' do
    before do
      queue.repeat_mode = Utils::RepeatMode::SONG
      queue.set_song(nil)
    end

    it 'stays on the same song when moving next' do
      queue.next

      expect(queue.current_song.title).to eq('Song 1')
      expect(queue.position).to eq(0)
    end
  end

  describe '#set_song' do
    it 'starts play at a given song rather than the first one' do
      third_song = coremodel.songs.find { |song| song.title == 'Song 3' }

      queue.set_song(third_song)

      expect(queue.current_song.title).to eq('Song 3')
    end

    it 'marks the started song as playing' do
      queue.set_song(nil)

      expect(queue.current_song.state).to eq(SongWidget::PLAYING)
    end
  end

  describe 'skipping a failed song' do
    it 'advances past a song marked FAILED when moving next' do
      queue.set_song(nil)
      # The queue holds duplicates of the collection's songs, so the
      # failure has to be set on the queued copy next() will land on.
      queue.get_next.validation = CoreSong::FAILED

      queue.next

      expect(queue.current_song.title).to eq('Song 3')
    end
  end

  describe '#end' do
    it 'resets every song back to UNPLAYED' do
      queue.set_song(nil)
      queue.next

      queue.end

      expect(coremodel.queue_model.to_a.map(&:state).uniq).to eq([SongWidget::UNPLAYED])
    end
  end
end
