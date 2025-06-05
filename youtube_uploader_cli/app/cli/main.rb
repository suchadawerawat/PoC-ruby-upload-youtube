# frozen_string_literal: true

require 'thor'
require_relative '../../lib/app_logger' # Adjusted path
require_relative '../gateways/cli_youtube_service_gateway'
require_relative '../gateways/csv_log_persistence_gateway' # Added
require_relative '../use_cases/default_upload_video' # Added
require_relative '../entities/video_details' # Added
require_relative '../entities/upload_log_entry' # Added (indirectly used by use case)
require 'use_cases/list_videos_use_case' # Existing
require 'entities/video_list_item' # Though not directly used by CLI, good for context
require 'dotenv/load' # Ensure ENV vars are loaded for the CLI

module Cli
  # Main class for the YouTube Uploader CLI using Thor.
  class Main < Thor
    # AppLogger.logger is initialized when app_logger.rb is required.
    # We assign it to a class instance variable for use within this class.
    @logger = AppLogger.logger
    # Optionally, log right after assignment to confirm it's working.
    # @logger.info("Cli::Main logger configured with level: #{@logger.level}")

    class << self
      attr_reader :logger
    end
    # Standard Thor options for help and version.
    class_option :help, type: :boolean, aliases: '-h', desc: 'Display usage information'
    class_option :version, type: :boolean, aliases: '-v', desc: 'Display version'

    desc "upload FILE_PATH", "Uploads a video to YouTube."
    option :title, type: :string, aliases: '-t', desc: "Title of the video on YouTube.", required: true
    option :description, type: :string, aliases: '-d', desc: "Description of the video."
    option :category_id, type: :string, aliases: '-c', desc: "YouTube category ID (e.g., '22' for People & Blogs).", required: true
    option :privacy_status, type: :string, aliases: '-p', default: Entities::VideoDetails::DEFAULT_PRIVACY_STATUS, desc: "Privacy status: public, private, or unlisted."
    option :tags, type: :array, aliases: '-g', desc: "Comma-separated list of tags for the video."
    option :log_path, type: :string, desc: "Custom path for the upload log CSV file." # For CsvLogPersistenceGateway
    def upload(file_path)
      self.class.logger.info("Starting 'upload' command for file: #{file_path}")
      if options[:version]
        invoke :version
        return
      end

      self.class.logger.debug("Upload options: #{options.inspect}")

      # Instantiate Gateways
      youtube_gateway = Gateways::CliYouTubeServiceGateway.new(self.class.logger)
      # Potentially authenticate if service is not already configured/authorized from a previous step
      # For MVP, we assume auth is handled separately by 'auth' command or credentials exist.
      # A more robust CLI might try to authenticate here if needed.
      # youtube_gateway.authenticate(config: { client_secret_path: ..., tokens_path: ..., app_name: ... })

      # Instantiate CsvLogPersistenceGateway:
      # Pass options[:log_path] directly. If nil, gateway's constructor will handle ENV and its own default.
      log_gateway = Gateways::CsvLogPersistenceGateway.new(
        logger: self.class.logger,
        log_file_path: options[:log_path]
      )

      # Instantiate Use Case
      upload_use_case = UseCases::DefaultUploadVideoUseCase.new(
        logger: self.class.logger,
        youtube_gateway: youtube_gateway,
        log_gateway: log_gateway
      )

      begin
        video_details = Entities::VideoDetails.new(
          file_path: file_path,
          title: options[:title],
          description: options[:description] || "", # Default to empty string if nil
          category_id: options[:category_id],
          privacy_status: options[:privacy_status], # Entity handles default
          tags: options[:tags] || [] # Entity handles default
        )
        self.class.logger.info("VideoDetails created: #{video_details.inspect}")
      rescue ArgumentError => e
        self.class.logger.error("Failed to create VideoDetails: #{e.message}")
        puts "ERROR: Invalid video details provided. #{e.message}" # User-friendly message
        exit(1) # Explicitly exit with error code
      end

      # Execute Use Case
      begin
        self.class.logger.info("Executing DefaultUploadVideoUseCase for: #{video_details.title}")
        result_log_entry = upload_use_case.execute(video_details: video_details)

        if result_log_entry.status == 'SUCCESS'
          puts "Video uploaded successfully!"
          puts "Title: #{result_log_entry.video_title}"
          # Display YouTube URL if available in the log entry
          puts "YouTube URL: #{result_log_entry.youtube_url}" if result_log_entry.youtube_url
          puts "Video ID: #{result_log_entry.details}" # details field contains Video ID on success
        else
          # Log error to console (user-facing)
          puts "Error uploading video: #{result_log_entry.details}" # details field contains error message on failure
          exit(1) # Explicitly exit with error code
        end
        self.class.logger.info("Upload command finished for: '#{file_path}'. Status: #{result_log_entry.status}")
      rescue StandardError => e
        # This catches unexpected errors from the use case execution itself,
        # though the use case is designed to catch gateway errors and return a FAILURE log entry.
        self.class.logger.fatal("An unexpected critical error occurred during the upload command: #{e.message}")
        self.class.logger.fatal(e.backtrace.join("\n"))
        puts "ERROR: An unexpected critical problem occurred. Please check logs for details. Message: #{e.message}"
        exit(1) # Explicitly exit with error code
      end
    end

    desc "auth", "Authenticates with Google to allow YouTube uploads."
    def auth
      self.class.logger.info("Starting 'auth' command.")
      puts 'Attempting to authenticate with Google...'
      config = {
        client_secret_path: ENV.fetch('GOOGLE_CLIENT_SECRET_PATH', 'config/client_secret.json'),
        tokens_path: ENV.fetch('YOUTUBE_TOKENS_PATH', 'config/tokens.yaml'),
        app_name: ENV.fetch('YOUTUBE_APP_NAME', 'Ruby YouTube Uploader CLI')
      }

      gateway = Gateways::CliYouTubeServiceGateway.new(self.class.logger)

      begin
        self.class.logger.debug("Authenticating with config: #{config.reject { |k, _v| k == :client_secret_path }}") # Avoid logging secrets
        # For CLI, the default user_interaction_provider in the gateway (STDIN.gets) will be used.
        youtube_service = gateway.authenticate(config: config)

        if youtube_service && youtube_service.authorization && youtube_service.authorization.access_token
          self.class.logger.info("Authentication successful. Tokens stored at: #{config[:tokens_path]}")
          puts 'Successfully authenticated and authorized.'
          puts "Tokens stored at: #{config[:tokens_path]}"
        else
          self.class.logger.warn("Authentication failed. No valid credentials obtained.")
          puts 'Authentication failed. No valid credentials obtained.'
        end
      rescue StandardError => e
        self.class.logger.error("An error occurred during authentication: #{e.message}")
        self.class.logger.error(e.backtrace.join("\n")) if ENV['YOUTUBE_UPLOADER_LOG_LEVEL'] == 'DEBUG'
        puts "An error occurred during authentication: #{e.message}"
        puts e.backtrace.join("\n") if ENV['YOUTUBE_UPLOADER_LOG_LEVEL'] == 'DEBUG'
      end
      self.class.logger.info("'auth' command finished.")
    end

    desc "version", "Prints the CLI version."
    def version
      self.class.logger.debug("Displaying version information.")
      # In a real app, you might load this from a VERSION file or constant
      puts "YouTube Uploader CLI version 0.1.0 (Placeholder)" # This could also be logged.
    end
    map %w[--version -v] => :version

    desc "list", "Lists videos from your YouTube account."
    option :max_results, type: :numeric, aliases: '-m', desc: "Maximum number of videos to list (default: 10, max: 50)."
    def list
      self.class.logger.info("Starting 'list' command.")
      config = {
        client_secret_path: ENV.fetch('GOOGLE_CLIENT_SECRET_PATH', 'config/client_secret.json'),
        tokens_path: ENV.fetch('YOUTUBE_TOKENS_PATH', 'config/tokens.yaml'),
        app_name: ENV.fetch('YOUTUBE_APP_NAME', 'Ruby YouTube Uploader CLI')
      }
      gateway = Gateways::CliYouTubeServiceGateway.new(self.class.logger)

      begin
        self.class.logger.debug("Authenticating for 'list' command...")
        # Authenticate to ensure @service is populated in the gateway
        # The authenticate method will either load existing credentials or guide through OAuth flow.
        puts "Authenticating..." # User-facing message
        authenticated_service = gateway.authenticate(config: config)

        unless authenticated_service && authenticated_service.authorization && authenticated_service.authorization.access_token
          self.class.logger.warn("Authentication failed or was cancelled. Cannot list videos.")
          puts "Authentication failed or was cancelled. Cannot list videos." # User-facing
          return
        end
        self.class.logger.info("Authentication successful for 'list' command.")
        puts "Authentication successful." # User-facing

        list_options = {}
        list_options[:max_results] = options[:max_results] if options[:max_results]
        self.class.logger.debug("List options: #{list_options}")

        puts "Fetching video list..." # User-facing
        videos = UseCases::ListVideosUseCase.execute(youtube_gateway: gateway, options: list_options)

        if videos.empty?
          self.class.logger.info("No videos found or an error occurred while fetching.")
          puts "No videos found or an error occurred while fetching." # User-facing
        else
          self.class.logger.info("Found #{videos.count} videos.")
          puts "Your Videos:" # User-facing
          videos.each_with_index do |video, index|
            puts "#{index + 1}. #{video.title} - #{video.youtube_url} (Published: #{video.published_at&.strftime('%Y-%m-%d') || 'N/A'})" # User-facing
          end
        end
      rescue StandardError => e
        self.class.logger.error("An error occurred during 'list' command: #{e.message}")
        self.class.logger.error(e.backtrace.join("\n")) if ENV['YOUTUBE_UPLOADER_LOG_LEVEL'] == 'DEBUG'
        puts "An error occurred: #{e.message}" # User-facing
        puts e.backtrace.join("\n") if ENV['YOUTUBE_UPLOADER_LOG_LEVEL'] == 'DEBUG'
      end
      self.class.logger.info("'list' command finished.")
    end

    # Make sure help is shown if no command is given
    def self.exit_on_failure?
      true
    end
  end
end
