# frozen_string_literal: true

require 'time' # For Time.parse and Time.now

module Entities
  # Represents a single log entry for a video upload.
  # This is a simple data structure (PORO) used to pass log information
  # to the logging gateway.
  class UploadLogEntry
    attr_reader :video_title, :file_path, :youtube_url, :upload_date, :status, :details

    VALID_STATUSES = %w[SUCCESS FAILURE].freeze

    # @param video_title [String] The title of the video on YouTube.
    # @param file_path [String] The original path to the video file.
    # @param youtube_url [String, nil] The URL of the uploaded video on YouTube (nil if failed).
    # @param upload_date [Time, String] The timestamp when the upload occurred (or was attempted).
    #                                  If String, it should be in ISO8601 format. Defaults to Time.now.
    # @param status [String] Status of the upload ('SUCCESS', 'FAILURE').
    # @param details [String] Video ID if successful, or error message if failed.
    def initialize(video_title:, file_path:, youtube_url: nil, upload_date: nil, status:, details:)
      @video_title = video_title
      @file_path = file_path
      @youtube_url = youtube_url
      @status = status
      @details = details

      if upload_date.nil?
        @upload_date = Time.now
      elsif upload_date.is_a?(String)
        begin
          @upload_date = Time.iso8601(upload_date)
        rescue ArgumentError
          raise ArgumentError, "Invalid upload_date string format. Please use ISO8601. Got: #{upload_date}"
        end
      elsif upload_date.is_a?(Time)
        @upload_date = upload_date
      else
        raise ArgumentError, "upload_date must be a Time object, an ISO8601 string, or nil. Got: #{upload_date.class}"
      end

      validate!
    end

    def to_h
      {
        video_title: @video_title,
        file_path: @file_path,
        youtube_url: @youtube_url,
        upload_date: @upload_date.iso8601,
        status: @status,
        details: @details
      }
    end

    def to_csv_row
      [
        @upload_date.iso8601,
        @file_path,
        @video_title,
        @status,
        @details, # Video ID or error message
        @youtube_url # youtube_url can be blank if status is 'FAILURE'
      ]
    end

    private

    def validate!
      raise ArgumentError, "Video title cannot be empty" if @video_title.nil? || @video_title.strip.empty?
      raise ArgumentError, "File path cannot be empty" if @file_path.nil? || @file_path.strip.empty?
      raise ArgumentError, "Upload date cannot be nil" if @upload_date.nil? # Should be set by initializer
      raise ArgumentError, "Status cannot be empty" if @status.nil? || @status.strip.empty?
      unless VALID_STATUSES.include?(@status)
        raise ArgumentError, "Status must be one of: #{VALID_STATUSES.join(', ')}. Got: '#{@status}'"
      end
      raise ArgumentError, "Details cannot be empty" if @details.nil? || @details.strip.empty?

      if @status == 'SUCCESS' && (@youtube_url.nil? || @youtube_url.strip.empty?)
        raise ArgumentError, "YouTube URL cannot be empty for a SUCCESSFUL upload"
      end
      if @status == 'FAILURE' && !@youtube_url.nil? && !@youtube_url.strip.empty?
        # Allow empty youtube_url for failure, but if provided, it's weird.
        # For now, let's not enforce this strictly, depends on how errors are reported.
        # Could log a warning if a URL is present on failure.
      end
    end
  end
end
