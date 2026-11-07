# frozen_string_literal: true

require_relative '../lib/core_song'

RSpec.describe CoreSong do
  let(:fields) do
    {
      id:                'song:1',
      album:             'A Album',
      album_urn:         'album:1',
      album_disc_number: '1',
      album_artist:      'An Album Artist',
      artist:            'A Track Artist',
      duration:          '185',
      title:             'A Title',
      track_number:      '3',
      url:               'file:///music/a.ogg',
      favorite:          false,
      last_played:       nil,
      play_count:        '2',
    }
  end

  subject(:song) { described_class.new(fields) }

  it 'reads the tag hash into its accessors' do
    expect(song.album).to eq('A Album')
    expect(song.album_urn).to eq('album:1')
    expect(song.album_disc_number).to eq(1)
    expect(song.artist).to eq('An Album Artist')
    expect(song.duration).to eq(185)
    expect(song.title).to eq('A Title')
    expect(song.track_number).to eq(3)
    expect(song.url).to eq('file:///music/a.ogg')
    expect(song.play_count).to eq(2)
    expect(song.favorite?).to be(false)
  end

  describe '#==' do
    it 'considers two songs with the same id equal, tags notwithstanding' do
      other = described_class.new(fields.merge(title: 'A Different Title'))

      expect(song).to eq(other)
    end

    it 'considers songs with different ids unequal' do
      other = described_class.new(fields.merge(id: 'song:2'))

      expect(song).not_to eq(other)
    end

    it 'is not equal to a non-CoreSong' do
      expect(song).not_to eq('song:1')
    end
  end

  describe '#hash' do
    it 'matches for songs with the same id, so they dedupe in a Hash/Set' do
      other = described_class.new(fields.merge(title: 'A Different Title'))

      expect(song.hash).to eq(other.hash)
    end
  end

  describe '#favorite=' do
    it 'notifies :favorite when the value changes' do
      seen = []
      song.on_notify { |name| seen << name }

      song.favorite = true

      expect(song.favorite?).to be(true)
      expect(seen).to include(:favorite)
    end

    it 'does not notify when the value does not change' do
      seen = []
      song.on_notify { |name| seen << name }

      song.favorite = false

      expect(seen).to eq([])
    end
  end

  describe '#validation' do
    it 'starts PENDING' do
      expect(song.validation).to eq(described_class::PENDING)
    end

    it 'notifies :validation when it changes' do
      seen = []
      song.on_notify { |name| seen << name }

      song.validation = described_class::FAILED

      expect(song.validation).to eq(described_class::FAILED)
      expect(seen).to include(:validation)
    end
  end

  describe '#bump_play_count' do
    it 'increments the play count and notifies :play_count' do
      seen = []
      song.on_notify { |name| seen << name }

      song.bump_play_count

      expect(song.play_count).to eq(3)
      expect(seen).to include(:play_count)
    end
  end

  describe '#last_played=' do
    it 'sets the value and notifies when given a truthy value' do
      now = Time.now.utc
      seen = []
      song.on_notify { |name| seen << name }

      song.last_played = now

      expect(song.last_played).to eq(now)
      expect(seen).to include(:last_played)
    end

    it 'leaves the value untouched when given nil' do
      song.last_played = Time.now.utc
      seen = []
      song.on_notify { |name| seen << name }

      song.last_played = nil

      expect(song.last_played).not_to be_nil
      expect(seen).to eq([])
    end
  end

  describe '#update' do
    it 'rereads every tag-derived field from the new hash' do
      song.update(fields.merge(title: 'New Title', track_number: '9'))

      expect(song.title).to eq('New Title')
      expect(song.track_number).to eq(9)
    end

    it 'notifies :updated' do
      seen = []
      song.on_notify { |name| seen << name }

      song.update(fields)

      expect(seen).to include(:updated)
    end
  end

  describe '#duplicate' do
    it 'returns a distinct, equal CoreSong carrying the same tags' do
      copy = song.duplicate

      expect(copy).not_to be(song)
      expect(copy).to eq(song)
      expect(copy.title).to eq(song.title)
    end

    it 'does not share mutable state with the original' do
      copy = song.duplicate
      copy.favorite = true

      expect(song.favorite?).to be(false)
    end
  end
end
