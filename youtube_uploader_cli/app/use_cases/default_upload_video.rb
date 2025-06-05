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
      @logger.info("Starting video upload use case for title: '#{video_details.title}'")
      @logger.debug("Video details for upload: #{video_details.inspect}") # Matched prompt

      upload_log_entry = nil

      begin
        youtube_video_response = @youtube_gateway.upload_video(video_details: video_details)

        video_id = youtube_video_response.id
        youtube_url = "https://www.youtube.com/watch?v=#{video_id}"

        @logger.info("Video uploaded successfully via gateway. YouTube Video ID: #{video_id}") # Matched prompt (using Video ID)

        upload_log_entry = Entities::UploadLogEntry.new(
          video_title: video_details.title,
          upload_date: Time.now, # UploadLogEntry handles UTC conversion
          status: 'SUCCESS',
          details: video_id,
          file_path: video_details.file_path,
          youtube_url: youtube_url
        )
      rescue Gateways::AuthenticationError => e
        @logger.error("Authentication error during upload for '#{video_details.title}': #{e.message}") # Matched prompt
        upload_log_entry = create_failure_log_entry(video_details, e.message)
      rescue Gateways::YouTubeUploadError => e
        @logger.error("YouTube upload error for '#{video_details.title}': #{e.message}") # Matched prompt
        upload_log_entry = create_failure_log_entry(video_details, e.message)
      rescue ArgumentError => e # Catch ArgumentErrors from gateway (e.g. file not found) or VideoDetails
        @logger.error("Argument error during upload for '#{video_details.title}': #{e.message}") # Matched prompt
        upload_log_entry = create_failure_log_entry(video_details, e.message)
      rescue StandardError => e
        @logger.error("Unexpected error during upload for '#{video_details.title}': #{e.class} - #{e.message}") # Matched prompt
        @logger.debug("Unexpected error backtrace: #{e.backtrace.join("\n")}")
        upload_log_entry = create_failure_log_entry(video_details, "Unexpected error: #{e.message}")
      ensure
        # Ensure log attempt happens even if an error occurs before upload_log_entry is set by try block
        # (e.g. error within the rescue blocks themselves before assignment)
        upload_log_entry ||= create_failure_log_entry(video_details, "Failed before log entry could be finalized")

        persist_log_entry(upload_log_entry)
      end

      @logger.info("Finished video upload use case for: '#{video_details.title}'. Final Status: #{upload_log_entry&.status}")
      upload_log_entry # Return the UploadLogEntry object
    end

    private

    def create_failure_log_entry(video_details, error_message)
      Entities::UploadLogEntry.new(
        video_title: video_details.title,
        upload_date: Time.now, # UploadLogEntry handles UTC conversion
        status: 'FAILURE',
        details: error_message, # Error message from gateway
        file_path: video_details.file_path,
        youtube_url: nil
      )
    end

    def persist_log_entry(entry)
      return unless entry # Should not happen with the ensure logic, but as a safeguard.

      @logger.debug("Preparing to save log entry: #{entry.inspect}") # Changed from to_h to inspect
      begin
        @log_gateway.save(upload_log_entry: entry) # Pass with keyword argument
        @logger.info("Upload log entry saved for video title: '#{entry.video_title}'")
      rescue StandardError => e
        @logger.error("Failed to save upload log entry for '#{entry.video_title}'. Error: #{e.message}")
        @logger.debug("Log saving error backtrace: #{e.backtrace.join("\n")}")
        # Do not let logging failure overshadow the primary operation's result.
      end
    end
  end
end
