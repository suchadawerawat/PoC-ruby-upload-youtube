# frozen_string_literal: true

module Entities
  # Represents a video item in a list, typically fetched from YouTube.
  # Contains essential details for display or further processing.
  class VideoListItem
    attr_reader :id, :title, :youtube_url, :published_at, :thumbnail_url

    # Initializes a new VideoListItem.
    #
    # @param id [String] The YouTube video ID.
    # @param title [String] The title of the video.
    # @param youtube_url [String] The full URL to the video on YouTube.
    # @param published_at [Time, String] The publication date and time of the video.
    # @param thumbnail_url [String, nil] The URL of a thumbnail image for the video, if available.
    def initialize(id:, title:, youtube_url:, published_at:, thumbnail_url: nil)
      @id = id
      @title = title
      @youtube_url = youtube_url
      @published_at = published_at
      @thumbnail_url = thumbnail_url
    end

    # Provides a hash representation of the video list item.
    #
    # @return [Hash] A hash containing the video list item's attributes.
    def to_h
      {
        id: id,
        title: title,
        youtube_url: youtube_url,
        published_at: published_at,
        thumbnail_url: thumbnail_url
      }
    end
  end
end
