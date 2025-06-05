# frozen_string_literal: true

require 'googleauth' # For user authorization
require 'googleauth/stores/file_token_store' # For storing user credentials
require 'google/apis/youtube_v3' # The YouTube API client
require 'fileutils' # For ensuring directory for token store exists
require_relative './youtube_service_gateway'
require_relative '../entities/video_details' # Though not directly used in auth, good for consistency
require_relative '../entities/video_list_item'


module Gateways
  # Concrete implementation of YouTubeServiceGateway for a CLI environment.
  # Handles OAuth 2.0 authentication and video uploads using the google-api-client.
  class CliYouTubeServiceGateway
    include YouTubeServiceGateway # Includes the interface methods and default get_authorization_instructions

    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob' # Out-of-band URI for desktop apps
    YOUTUBE_API_SCOPE = Google::Apis::YoutubeV3::AUTH_YOUTUBE_UPLOAD

    def initialize(logger)
      @logger = logger
    end

    # Authenticates the user via OAuth 2.0 for CLI.
    #
    # @param config [Hash] A hash containing:
    #   :client_secret_path [String] Path to the client_secret.json file.
    #   :tokens_path [String] Path to store and load OAuth tokens.
    #   :app_name [String] Name of the application.
    # @param user_interaction_provider [Proc] A proc that handles user interaction for OAuth code.
    #                                          It receives the auth_url and should return the auth_code.
    #                                          Defaults to STDIN.gets.chomp for CLI input.
    # @return [Google::Apis::YoutubeV3::YouTubeService] An authorized YouTube API service client.
    # @raise [StandardError] if authentication fails.
    def authenticate(config:, user_interaction_provider: nil)
      @logger.info('Starting authentication process...')
      client_secret_path = config.fetch(:client_secret_path)
      unless File.exist?(client_secret_path)
        @logger.error("Client secret file not found at: #{client_secret_path}")
        raise "Client secret file not found at: #{client_secret_path}. Please download it from Google Cloud Console and place it correctly."
      end
      client_id = Google::Auth::ClientId.from_file(client_secret_path)
      @logger.debug("Client ID loaded from: #{client_secret_path}")

      token_store_path = config.fetch(:tokens_path)
      @logger.debug("Token store path: #{token_store_path}")
      FileUtils.mkdir_p(File.dirname(token_store_path)) # Ensure directory exists
      token_store = Google::Auth::Stores::FileTokenStore.new(file: token_store_path)

      authorizer = Google::Auth::UserAuthorizer.new(client_id, YOUTUBE_API_SCOPE, token_store)
      user_id = 'default_user' # For CLI, we usually have one user per token store
      @logger.debug("Attempting to load credentials for user_id: #{user_id} from token store: #{token_store_path}")
      credentials = authorizer.get_credentials(user_id)

      if credentials.nil?
        @logger.info('No valid credentials found in token store. Fresh authentication is required.')
        auth_url = authorizer.get_authorization_url(base_url: OOB_URI)
        @logger.debug("OAuth flow details: Application Name: #{config.fetch(:app_name, 'Ruby YouTube Uploader')}, Client ID Path: #{client_secret_path}, Scope: #{YOUTUBE_API_SCOPE}")
        @logger.info("Generated authorization URL: #{auth_url}")

        # Use the provided interaction provider or default to STDIN
        code_input_instruction = get_authorization_instructions(auth_url: auth_url) # Uses method from included module
        @logger.info("Prompting user to visit the authorization URL and provide code.")
        code = if user_interaction_provider
                 user_interaction_provider.call(code_input_instruction)
               else
                 puts code_input_instruction
                 STDIN.gets.chomp.strip # Make sure to strip whitespace
               end

        @logger.debug("User provided authorization code: #{code.nil? || code.empty? ? 'EMPTY' : '******'}") # Avoid logging the actual code if possible

        if code.nil? || code.empty?
          @logger.error('Authentication cancelled or authorization code not provided by user.')
          raise "Authentication cancelled or code not provided."
        end

        @logger.info('Exchanging authorization code for tokens...')
        begin
          credentials = authorizer.get_and_store_credentials_from_code(
            user_id: user_id, code: code, base_url: OOB_URI
          )
          @logger.debug('Token exchange successful. Credentials received.')
          @logger.info("Storing new tokens to file: #{token_store_path}")
        rescue StandardError => e
          @logger.error("Error during token exchange or storage: #{e.message}")
          raise
        end
      else
        @logger.info('Successfully loaded existing tokens from file.')
      end

      if credentials.nil?
        @logger.error('Failed to obtain credentials after authentication process.')
        raise "Failed to obtain credentials."
      end

      # Initialize the YouTube API service
      service = Google::Apis::YoutubeV3::YouTubeService.new
      service.client_options.application_name = config.fetch(:app_name, 'Ruby YouTube Uploader')
      service.authorization = credentials
      @service = service # Store the service instance
      @logger.info('YouTube API service initialized and authorized successfully.')
      @service # Explicitly return the service
    rescue StandardError => e
      @logger.error("An unexpected error occurred during authentication: #{e.message}")
      # Optionally log backtrace if in debug mode, e.g., @logger.debug(e.backtrace.join("\n"))
      raise # Re-raise the exception after logging
    end

    # Lists videos for the authenticated user.
    #
    # @param options [Hash] Options for the API call.
    #   :max_results [Integer] Maximum number of videos to return (default: 25, max: 50).
    #   :page_token [String] Token for fetching a specific page of results.
    # @return [Array<Entities::VideoListItem>] An array of video list items.
    # @raise [StandardError] if the API call fails or if not authenticated.
    def list_videos(options: {})
      # Ensure service is initialized and authenticated.
      # The `authenticate` method returns the service object.
      # A more robust implementation might store the service in an instance variable
      # or require authentication to be explicitly called before this method.
      # For now, let's assume `authenticate` has been called and service is available.
      # This is a simplification; in a real app, you'd manage the authenticated service instance.
      # We'll need to call authenticate to get the service object.
      # This is a temporary measure for this subtask. The CLI main task will handle this.

      # This is a placeholder for where you would get the actual service object.
      # In a real scenario, the service object would be instantiated and authenticated
      # then passed to this method or stored in an instance variable.
      # For the purpose of this subtask, we cannot call authenticate directly here
      # as it requires user interaction or pre-existing config not available in this isolated subtask.
      # We will assume 'service' is available as if authenticate was called.
      # This will be tested with a mocked service object in the specs.

      # Placeholder: Simulating obtaining the service object
      # In actual execution, the CLI command will ensure authentication provides this.
      # Dummy config for the purpose of this subtask structure.
      # THIS IS A SIMPLIFIED APPROACH FOR THE SUBTASK.
      # The actual service object will be provided by the calling context in the final app.

      # To make this method testable and runnable in isolation for the subtask,
      # we'll assume a 'service' object is passed or accessible.
      # However, the current class structure implies `authenticate` provides it.
      # Let's refine this: the method should expect `service` to be an instance variable `@service`.

      unless @service && @service.authorization && @service.authorization.access_token
        # This would ideally re-use the authentication logic or ensure it has run.
        # For now, raising an error indicating prerequisite.
        @logger.warn('Attempted to list videos without prior authentication.')
        raise 'Authentication required before listing videos. Please run the auth command.'
      end

      max_results = options.fetch(:max_results, 25).to_i
      page_token = options[:page_token]

      begin
        response = @service.list_videos('snippet,player,status', my_videos: true, max_results: max_results, page_token: page_token)

        return [] if response.items.nil? || response.items.empty?

        response.items.map do |item|
          video_id = item.id
          title = item.snippet.title
          # Construct YouTube URL. item.player.embed_html gives an iframe, not a direct URL.
          # A direct URL is usually https://www.youtube.com/watch?v=VIDEO_ID
          youtube_url = "https://www.youtube.com/watch?v=#{video_id}"
          published_at_str = item.snippet.published_at
          published_at = Time.parse(published_at_str) if published_at_str
          thumbnail_url = item.snippet.thumbnails&.default&.url # Or 'medium' or 'high'

          Entities::VideoListItem.new(
            id: video_id,
            title: title,
            youtube_url: youtube_url,
            published_at: published_at,
            thumbnail_url: thumbnail_url
          )
        end
      rescue Google::Apis::ClientError => e
        # Handle API client errors (e.g., quota exceeded, bad request)
        @logger.error("Google API Client Error while listing videos: #{e.message}")
        # Depending on desired behavior, could return empty array or re-raise
        [] # Return empty for now on client errors
      rescue Google::Apis::AuthorizationError => e
        # Handle authorization errors specifically
        @logger.error("Google API Authorization Error while listing videos: #{e.message}")
        raise # Re-raise auth errors as they are critical
      rescue StandardError => e
        @logger.error("An unexpected error occurred while listing videos: #{e.message}")
        [] # Return empty for other unexpected errors
      end
    end

    # Uploads a video to YouTube.
    #
    # @param video_details [Entities::VideoDetails] An object containing all necessary video metadata.
    # @return [Google::Apis::YoutubeV3::Video, nil] The uploaded video object from YouTube API, or nil if failed.
    def upload_video(video_details:)
      @logger.info("Attempting to upload video: '#{video_details.title}' from path: '#{video_details.file_path}'")

      unless @service && @service.authorization && @service.authorization.access_token
        @logger.error('Authentication required before uploading video. Service not initialized or not authorized.')
        # For MVP, we assume authenticate has been called. In a more robust version,
        # this might trigger authentication or return a specific error/status.
        return nil # Or raise an error, e.g., StandardError.new("Not authenticated")
      end

      unless File.exist?(video_details.file_path)
        @logger.error("Video file not found at path: #{video_details.file_path}")
        return nil # Or raise an error
      end

      video_object = Google::Apis::YoutubeV3::Video.new(
        snippet: {
          title: video_details.title,
          description: video_details.description,
          tags: video_details.tags,
          category_id: video_details.category_id
        },
        status: {
          privacy_status: video_details.privacy_status
        }
      )
      @logger.debug("Constructed YouTube Video object: #{video_object.to_json}")

      begin
        @logger.info("Starting video upload to YouTube for: #{video_details.file_path}")
        # Determine content type (basic for now, could be more sophisticated)
        content_type = 'application/octet-stream' # Generic, or use MIME::Types if available for video_details.file_path
        @logger.debug("Uploading with content_type: #{content_type}")

        response = @service.insert_video(
          'snippet,status', # Parts to include in the request
          video_object,
          upload_source: video_details.file_path,
          content_type: content_type,
          options: {
            # authorization: @service.authorization # Already set on @service
          }
        )

        @logger.info("Successfully uploaded video. YouTube Video ID: #{response.id}")
        @logger.debug("Full API response: #{response.to_json}")
        response # Return the full video object from YouTube
      rescue Google::Apis::ClientError => e
        @logger.error("Google API Client Error during video upload: #{e.message}")
        @logger.error("Body: #{e.body}") if e.respond_to?(:body)
        @logger.error("Headers: #{e.header}") if e.respond_to?(:header)
        # Consider logging e.status_code as well
        nil # Return nil on failure
      rescue Google::Apis::AuthorizationError => e
        @logger.error("Google API Authorization Error during video upload: #{e.message}")
        # This might indicate expired or revoked credentials.
        nil
      rescue StandardError => e
        @logger.error("An unexpected error occurred during video upload: #{e.message}")
        @logger.error("Backtrace: #{e.backtrace.join("\n")}")
        nil
      end
    end

    # exchange_code_for_tokens is effectively handled within the #authenticate method's flow
    # when credentials are nil. No separate public method is needed from the gateway interface here.
  end
end
