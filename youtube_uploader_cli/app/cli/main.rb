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
    @logger = AppLogger.get_logger
    @logger.info("Logger initialized with level: #{@logger.level}")

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
      Main.logger.info("Starting 'upload' command for file: #{file_path}")
      if options[:version]
        invoke :version
        return
      end

      Main.logger.debug("Upload options: #{options.inspect}")

      # Instantiate Gateways
      youtube_gateway = Gateways::CliYouTubeServiceGateway.new(Main.logger)
      # Potentially authenticate if service is not already configured/authorized from a previous step
      # For MVP, we assume auth is handled separately by 'auth' command or credentials exist.
      # A more robust CLI might try to authenticate here if needed.
      # youtube_gateway.authenticate(config: { client_secret_path: ..., tokens_path: ..., app_name: ... })

      log_file_to_use = options[:log_path] || Gateways::CsvLogPersistenceGateway::DEFAULT_LOG_FILE_PATH
      log_gateway = Gateways::CsvLogPersistenceGateway.new(logger: Main.logger, log_file_path: log_file_to_use)

      # Instantiate Use Case
      upload_use_case = UseCases::DefaultUploadVideoUseCase.new(
        logger: Main.logger,
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
        Main.logger.info("VideoDetails created: #{video_details.inspect}")
      rescue ArgumentError => e
        Main.logger.error("Failed to create VideoDetails: #{e.message}")
        puts "ERROR: Invalid video details provided. #{e.message}"
        return # Exit if details are invalid
      end

      # Execute Use Case
      begin
        Main.logger.info("Executing DefaultUploadVideoUseCase for: #{video_details.title}")
        result_log_entry = upload_use_case.execute(video_details: video_details)

        if result_log_entry.status == 'SUCCESS'
          puts "Video uploaded successfully!"
          puts "Title: #{result_log_entry.video_title}"
          puts "YouTube URL: #{result_log_entry.youtube_url}"
          puts "Video ID: #{result_log_entry.details}"
        else
          puts "Video upload failed."
          puts "Title: #{result_log_entry.video_title}"
          puts "Reason: #{result_log_entry.details}"
        end
        Main.logger.info("Upload command finished for: #{file_path}. Status: #{result_log_entry.status}")
      rescue StandardError => e
        Main.logger.fatal("An unexpected error occurred during the upload process: #{e.message}")
        Main.logger.fatal(e.backtrace.join("\n"))
        puts "ERROR: An unexpected problem occurred. Please check logs. Details: #{e.message}"
      end
    end

    desc "auth", "Authenticates with Google to allow YouTube uploads."
    def auth
      puts 'Attempting to authenticate with Google...'
      config = {
        client_secret_path: ENV.fetch('GOOGLE_CLIENT_SECRET_PATH', 'config/client_secret.json'),
        tokens_path: ENV.fetch('YOUTUBE_TOKENS_PATH', 'config/tokens.yaml'),
        app_name: ENV.fetch('YOUTUBE_APP_NAME', 'Ruby YouTube Uploader CLI')
      }

      gateway = Gateways::CliYouTubeServiceGateway.new(Main.logger)

      begin
        # For CLI, the default user_interaction_provider in the gateway (STDIN.gets) will be used.
        youtube_service = gateway.authenticate(config: config)
        # Check for service, its authorization object, and the presence of an access token
        if youtube_service && youtube_service.authorization && youtube_service.authorization.access_token
          puts 'Successfully authenticated and authorized.'
          puts "Tokens stored at: #{config[:tokens_path]}"
        else
          puts 'Authentication failed. No valid credentials obtained.'
        end
      rescue StandardError => e
        puts "An error occurred during authentication: #{e.message}"
        puts e.backtrace.join("\n") if ENV['DEBUG'] == 'true' # Optional debug output
      end
    end

    desc "version", "Prints the CLI version."
    def version
      Main.logger.debug("Displaying version information.")
      # In a real app, you might load this from a VERSION file or constant
      puts "YouTube Uploader CLI version 0.1.0 (Placeholder)"
    end
    map %w[--version -v] => :version

    desc "list", "Lists videos from your YouTube account."
    option :max_results, type: :numeric, aliases: '-m', desc: "Maximum number of videos to list (default: 10, max: 50)."
    def list
      config = {
        client_secret_path: ENV.fetch('GOOGLE_CLIENT_SECRET_PATH', 'config/client_secret.json'),
        tokens_path: ENV.fetch('YOUTUBE_TOKENS_PATH', 'config/tokens.yaml'),
        app_name: ENV.fetch('YOUTUBE_APP_NAME', 'Ruby YouTube Uploader CLI')
      }
      gateway = Gateways::CliYouTubeServiceGateway.new(Main.logger)

      begin
        # Authenticate to ensure @service is populated in the gateway
        # The authenticate method will either load existing credentials or guide through OAuth flow.
        puts "Authenticating..."
        authenticated_service = gateway.authenticate(config: config)

        unless authenticated_service && authenticated_service.authorization && authenticated_service.authorization.access_token
          puts "Authentication failed or was cancelled. Cannot list videos."
          return
        end
        puts "Authentication successful."

        list_options = {}
        list_options[:max_results] = options[:max_results] if options[:max_results]

        puts "Fetching video list..."
        videos = UseCases::ListVideosUseCase.execute(youtube_gateway: gateway, options: list_options)

        if videos.empty?
          puts "No videos found or an error occurred while fetching."
        else
          puts "Your Videos:"
          videos.each_with_index do |video, index|
            puts "#{index + 1}. #{video.title} - #{video.youtube_url} (Published: #{video.published_at&.strftime('%Y-%m-%d %H:%M:%S') || 'N/A'})"
          end
        end
      rescue StandardError => e
        puts "An error occurred: #{e.message}"
        puts e.backtrace.join("
") if ENV['DEBUG'] == 'true'
      end
    end

    # Make sure help is shown if no command is given
    def self.exit_on_failure?
      true
    end
  end
end
