# frozen_string_literal: true

module Entities
  # Represents the metadata for a video to be uploaded.
  # This is a simple data structure (PORO) used to pass video information
  # between layers of the application.
  class VideoDetails
    attr_reader :file_path, :title, :description, :tags, :category_id, :privacy_status

    # @param file_path [String] Absolute path to the video file.
    # @param title [String] Title of the video on YouTube.
    # @param description [String] Description of the video on YouTube.
    # @param tags [Array<String>] Tags for the video.
    # @param category_id [String] YouTube category ID (e.g., "22" for People & Blogs).
    # @param privacy_status [String] Privacy status ('public', 'private', 'unlisted').
    def initialize(file_path:, title:, description:, tags: [], category_id:, privacy_status:)
      @file_path = file_path
      @title = title
      @description = description
      @tags = tags
      @category_id = category_id
      @privacy_status = privacy_status

      validate!
    end

    private

    def validate!
      raise ArgumentError, "File path cannot be empty" if file_path.nil? || file_path.strip.empty?
      raise ArgumentError, "Title cannot be empty" if title.nil? || title.strip.empty?
      # Description can be empty
      raise ArgumentError, "Category ID cannot be empty" if category_id.nil? || category_id.strip.empty?
      raise ArgumentError, "Privacy status cannot be empty" if privacy_status.nil? || privacy_status.strip.empty?
      unless %w[public private unlisted].include?(privacy_status)
        raise ArgumentError, "Privacy status must be one of: public, private, unlisted"
      end
      raise ArgumentError, "Tags must be an array" unless tags.is_a?(Array)
    end
  end
end
