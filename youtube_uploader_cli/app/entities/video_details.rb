# frozen_string_literal: true

module Entities
  # Represents the metadata for a video to be uploaded.
  # This is a simple data structure (PORO) used to pass video information
  # between layers of the application.
  class VideoDetails
    attr_reader :file_path, :title, :description, :tags, :category_id, :privacy_status

    VALID_PRIVACY_STATUSES = %w[public private unlisted].freeze
    DEFAULT_PRIVACY_STATUS = 'private'.freeze
    DEFAULT_TAGS = [].freeze

    # @param file_path [String] Absolute path to the video file.
    # @param title [String] Title of the video on YouTube.
    # @param description [String] Description of the video on YouTube.
    # @param category_id [String] YouTube category ID (e.g., "22" for People & Blogs).
    # @param privacy_status [String] Privacy status ('public', 'private', 'unlisted'). Defaults to 'private'.
    # @param tags [Array<String>] Tags for the video. Defaults to an empty array.
    def initialize(file_path:, title:, description:, category_id:, privacy_status: DEFAULT_PRIVACY_STATUS, tags: DEFAULT_TAGS)
      @file_path = file_path
      @title = title
      @description = description
      @category_id = category_id
      @privacy_status = privacy_status || DEFAULT_PRIVACY_STATUS
      @tags = tags || DEFAULT_TAGS

      validate!
    end

    def to_s
      "VideoDetails(file_path: '#{@file_path}', title: '#{@title}', description: '#{@description}', "\
      "privacy_status: '#{@privacy_status}', tags: #{@tags.inspect}, category_id: '#{@category_id}')"
    end

    alias_method :inspect, :to_s

    private

    def validate!
      if @file_path.nil? || @file_path.strip.empty?
        raise ArgumentError, "File path cannot be blank"
      end
      # Title can be empty according to YouTube, but let's assume we want it for our app
      if @title.nil? || @title.strip.empty?
        raise ArgumentError, "Title cannot be blank"
      end
      # Description can be blank.
      if @category_id.nil? || @category_id.strip.empty?
        raise ArgumentError, "Category ID cannot be blank"
      end
      unless VALID_PRIVACY_STATUSES.include?(@privacy_status)
        raise ArgumentError, "Privacy status must be one of: #{VALID_PRIVACY_STATUSES.join(', ')}. Got: '#{@privacy_status}'"
      end
      unless @tags.is_a?(Array)
        raise ArgumentError, "Tags must be an array. Got: #{@tags.class}"
      end
      if @tags.any? { |tag| !tag.is_a?(String) }
        raise ArgumentError, "All tags must be strings."
      end
    end
  end
end
