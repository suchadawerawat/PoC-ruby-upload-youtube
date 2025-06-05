# frozen_string_literal: true

require 'time' # For Time.parse and Time.now

module Entities
  # Represents a single log entry for a video upload.
  # This is a simple data structure (PORO) used to pass log information
  # to the logging gateway.
  class UploadLogEntry
    attr_reader :upload_timestamp, :input_video_name, :youtube_url, :title, :status

    # @param upload_timestamp [Time] The timestamp when the upload occurred.
    # @param input_video_name [String] The original filename or identifier of the input video.
    # @param youtube_url [String] The URL of the uploaded video on YouTube.
    # @param title [String] The title of the video on YouTube.
    # @param status [String] Status of the upload ('success', 'failure').
    def initialize(upload_timestamp:, input_video_name:, youtube_url:, title:, status:)
      @upload_timestamp = upload_timestamp.is_a?(String) ? Time.parse(upload_timestamp) : upload_timestamp
      @input_video_name = input_video_name
      @youtube_url = youtube_url
      @title = title
      @status = status

      validate!
    end

    def to_h
      {
        upload_timestamp: @upload_timestamp.iso8601,
        input_video_name: @input_video_name,
        youtube_url: @youtube_url,
        title: @title,
        status: @status
      }
    end

    def to_csv_row
      [
        @upload_timestamp.iso8601,
        @input_video_name,
        @title,
        @status,
        @youtube_url # youtube_url last as it can be long
      ]
    end

    private

    def validate!
      raise ArgumentError, "Upload timestamp cannot be nil" if @upload_timestamp.nil?
      raise ArgumentError, "Input video name cannot be empty" if @input_video_name.nil? || @input_video_name.strip.empty?
      # youtube_url can be empty if status is 'failure'
      if status == 'success' && (@youtube_url.nil? || @youtube_url.strip.empty?)
        raise ArgumentError, "YouTube URL cannot be empty for a successful upload"
      end
      raise ArgumentError, "Title cannot be empty" if @title.nil? || @title.strip.empty?
      raise ArgumentError, "Status cannot be empty" if @status.nil? || @status.strip.empty?
      unless %w[success failure].include?(@status)
        raise ArgumentError, "Status must be 'success' or 'failure'"
      end
    end
  end
end
