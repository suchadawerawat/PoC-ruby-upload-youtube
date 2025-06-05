# frozen_string_literal: true

require_relative '../entities/video_details'
require_relative '../entities/upload_log_entry'
require_relative '../gateways/youtube_service_gateway' # Interface
require_relative '../gateways/log_persistence_gateway' # Interface
require_relative 'upload_video' # Use case interface

module UseCases
  # Concrete implementation of the UploadVideoUseCase.
  # Orchestrates video upload via a YouTube gateway and logs the outcome via a log persistence gateway.
  class DefaultUploadVideoUseCase
    # @param logger [Logger] The application logger.
    # @param youtube_gateway [Gateways::YouTubeServiceGateway] Gateway for YouTube API interactions.
    # @param log_gateway [Gateways::LogPersistenceGateway] Gateway for persisting upload logs.
    def initialize(logger:, youtube_gateway:, log_gateway:)
      @logger = logger
      @youtube_gateway = youtube_gateway
      @log_gateway = log_gateway
      @logger.info("#{self.class.name} initialized.")
    end

    # Executes the video upload process.
    #
    # @param video_details [Entities::VideoDetails] The details of the video to upload.
    # @return [Entities::UploadLogEntry] The log entry for the upload attempt.
    def execute(video_details:)
      @logger.info("Starting video upload use case for: #{video_details.title}")
      @logger.debug("Video details: #{video_details.inspect}")

      upload_result = @youtube_gateway.upload_video(video_details: video_details)

      log_entry = if upload_result && upload_result.id
                    @logger.info("Video uploaded successfully. YouTube Video ID: #{upload_result.id}")
                    youtube_url = "https://www.youtube.com/watch?v=#{upload_result.id}"
                    Entities::UploadLogEntry.new(
                      video_title: video_details.title,
                      file_path: video_details.file_path,
                      youtube_url: youtube_url,
                      status: 'SUCCESS',
                      details: upload_result.id, # Store Video ID in details
                      upload_date: Time.now
                    )
                  else
                    @logger.error("Video upload failed for: #{video_details.title}")
                    Entities::UploadLogEntry.new(
                      video_title: video_details.title,
                      file_path: video_details.file_path,
                      youtube_url: nil,
                      status: 'FAILURE',
                      details: 'Upload failed via YouTubeServiceGateway. Check gateway logs for more information.',
                      upload_date: Time.now
                    )
                  end

      @logger.debug("Constructed log entry: #{log_entry.to_h}")

      begin
        @log_gateway.save(log_entry)
        @logger.info("Upload log entry saved successfully for: #{video_details.title}")
      rescue StandardError => e
        @logger.error("Failed to save upload log entry for: #{video_details.title}. Error: #{e.message}")
        # The use case should still return the log_entry so the primary operation's outcome is clear,
        # even if logging the outcome failed.
      end

      log_entry # Return the log entry as the result of the use case
    end
  end
end
