# frozen_string_literal: true

require_relative '../lib/utils'

RSpec.describe Utils do
  describe '.artist_from' do
    it 'prefers the album artist' do
      expect(Utils.artist_from(album_artist: 'Album Artist', artist: 'Track Artist')).to eq('Album Artist')
    end

    it 'falls back to the track artist' do
      expect(Utils.artist_from(album_artist: '', artist: 'Track Artist')).to eq('Track Artist')
    end

    it 'falls back to "Unknown Artist" when neither tag is set' do
      expect(Utils.artist_from(album_artist: nil, artist: nil)).to eq('Unknown Artist')
    end
  end

  describe '.title_from' do
    it 'returns the title tag when present' do
      expect(Utils.title_from(title: 'A Song', url: 'file:///music/a_song.ogg')).to eq('A Song')
    end

    it 'falls back to the file basename with underscores turned into spaces' do
      expect(Utils.title_from(title: '', url: 'file:///music/a_song.ogg')).to eq('a song.ogg')
    end

    it 'falls back to "NO URL" when there is no title and no url' do
      expect(Utils.title_from(title: '', url: nil)).to eq('NO URL')
    end
  end

  describe '.seconds_to_string' do
    it 'formats whole minutes and seconds' do
      expect(Utils.seconds_to_string(125)).to eq('2:05')
    end

    it 'formats zero as 0:00' do
      expect(Utils.seconds_to_string(0)).to eq('0:00')
    end

    it 'takes the absolute value of a negative duration' do
      expect(Utils.seconds_to_string(-5)).to eq('0:05')
    end
  end

  describe '.normalize_caseless' do
    it 'downcases and casefolds accented characters consistently' do
      expect(Utils.normalize_caseless('Café')).to eq(Utils.normalize_caseless('CAFÉ'))
    end

    it 'treats a nil as an empty string' do
      expect(Utils.normalize_caseless(nil)).to eq('')
    end
  end

  describe '.natural_sort_names' do
    it 'sorts numbers within names in natural order, not lexical order' do
      expect(Utils.natural_sort_names('Album 3', 'Album 10')).to eq(Gtk::Ordering::SMALLER)
      expect(Utils.natural_sort_names('Album 10', 'Album 3')).to eq(Gtk::Ordering::LARGER)
    end

    it 'treats case-insensitively equal names as equal' do
      expect(Utils.natural_sort_names('abc', 'ABC')).to eq(Gtk::Ordering::EQUAL)
    end
  end

  describe '.int_from' do
    it 'parses a numeric field' do
      expect(Utils.int_from({ track_number: '7' }, :track_number)).to eq(7)
    end

    it 'returns zero when the field is missing' do
      expect(Utils.int_from({}, :track_number)).to eq(0)
    end
  end

  describe Utils::RepeatMode do
    describe '.from_nick' do
      it 'finds the mode by its settings nick' do
        expect(Utils::RepeatMode.from_nick('shuffle')).to eq(Utils::RepeatMode::SHUFFLE)
      end

      it 'falls back to NONE for an unknown nick' do
        expect(Utils::RepeatMode.from_nick('bogus')).to eq(Utils::RepeatMode::NONE)
      end
    end

    describe '.from_value' do
      it 'finds the mode by its stored integer value' do
        expect(Utils::RepeatMode.from_value(2)).to eq(Utils::RepeatMode::ALL)
      end

      it 'falls back to NONE for an unknown value' do
        expect(Utils::RepeatMode.from_value(99)).to eq(Utils::RepeatMode::NONE)
      end
    end

    it 'round trips every mode through its nick' do
      Utils::RepeatMode::ALL_MODES.each do |mode|
        expect(Utils::RepeatMode.from_nick(mode.nick)).to eq(mode)
      end
    end
  end

  describe Utils::Observable do
    let(:observable_class) do
      Class.new do
        include Utils::Observable

        def bump = notify_property(:changed)
      end
    end

    it 'calls every registered listener with the property name' do
      observable = observable_class.new
      seen = []
      observable.on_notify { |name| seen << name }

      observable.bump

      expect(seen).to eq([:changed])
    end

    it 'stops calling a listener once it is removed' do
      observable = observable_class.new
      seen = []
      listener = observable.on_notify { |name| seen << name }
      observable.off_notify(listener)

      observable.bump

      expect(seen).to eq([])
    end

    it 'supports more than one listener' do
      observable = observable_class.new
      first_calls = 0
      second_calls = 0
      observable.on_notify { first_calls += 1 }
      observable.on_notify { second_calls += 1 }

      observable.bump

      expect(first_calls).to eq(1)
      expect(second_calls).to eq(1)
    end
  end
end
