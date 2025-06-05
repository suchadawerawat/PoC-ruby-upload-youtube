# frozen_string_literal: true

require 'spec_helper'
require 'entities/video_list_item' # Adjust path as necessary based on spec_helper load path

RSpec.describe Entities::VideoListItem do
  describe '#initialize' do
    it 'assigns all attributes correctly' do
      id = 'dQw4w9WgXcQ'
      title = 'Rick Astley - Never Gonna Give You Up (Official Music Video)'
      youtube_url = "https://www.youtube.com/watch?v=#{id}"
      published_at_time = Time.new(1987, 7, 27)
      thumbnail_url = 'https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg'

      item = Entities::VideoListItem.new(
        id: id,
        title: title,
        youtube_url: youtube_url,
        published_at: published_at_time,
        thumbnail_url: thumbnail_url
      )

      expect(item.id).to eq(id)
      expect(item.title).to eq(title)
      expect(item.youtube_url).to eq(youtube_url)
      expect(item.published_at).to eq(published_at_time)
      expect(item.thumbnail_url).to eq(thumbnail_url)
    end

    it 'assigns thumbnail_url as nil if not provided' do
      item = Entities::VideoListItem.new(
        id: 'test_id',
        title: 'Test Video',
        youtube_url: 'http://example.com/video',
        published_at: Time.now
      )
      expect(item.thumbnail_url).to be_nil
    end
  end

  describe '#to_h' do
    it 'returns a hash representation of the item' do
      id = 'videoId123'
      title = 'My Awesome Video'
      youtube_url = 'https://youtube.com/watch?v=videoId123'
      published_at_time = Time.parse('2023-01-15T10:00:00Z')
      thumbnail_url = 'https://example.com/thumb.jpg'

      item = Entities::VideoListItem.new(
        id: id,
        title: title,
        youtube_url: youtube_url,
        published_at: published_at_time,
        thumbnail_url: thumbnail_url
      )

      expected_hash = {
        id: id,
        title: title,
        youtube_url: youtube_url,
        published_at: published_at_time,
        thumbnail_url: thumbnail_url
      }
      expect(item.to_h).to eq(expected_hash)
    end

    it 'returns a hash with nil thumbnail_url if it was not provided' do
      published_at_time = Time.now
      item = Entities::VideoListItem.new(
        id: 'another_id',
        title: 'Another Video',
        youtube_url: 'http://example.com/another',
        published_at: published_at_time
      )

      expected_hash = {
        id: 'another_id',
        title: 'Another Video',
        youtube_url: 'http://example.com/another',
        published_at: published_at_time,
        thumbnail_url: nil
      }
      expect(item.to_h).to eq(expected_hash)
    end
  end
end
