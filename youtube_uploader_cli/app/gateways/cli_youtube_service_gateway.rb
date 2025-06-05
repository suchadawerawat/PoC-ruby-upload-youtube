# frozen_string_literal: true

require 'googleauth' # For user authorization
require 'googleauth/stores/file_token_store' # For storing user credentials
require 'google/apis/youtube_v3' # The YouTube API client
require 'fileutils' # For ensuring directory for token store exists
require_relative './youtube_service_gateway'
require_relative '../entities/video_details' # Though not directly used in auth, good for consistency
require_relative '../entities/video_list_item'


module Gateways
  # Custom error for YouTube upload failures
  class YouTubeUploadError < StandardError; end
  class AuthenticationError < StandardError; end

  # Concrete implementation of YouTubeServiceGateway for a CLI environment.
  # Handles OAuth 2.0 authentication and video uploads using the google-api-client.
  class CliYouTubeServiceGateway
    include YouTubeServiceGateway # Includes the interface methods and default get_authorization_instructions

    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob' # Out-of-band URI for desktop apps
    YOUTUBE_API_SCOPE = [Google::Apis::YoutubeV3::AUTH_YOUTUBE_UPLOAD, Google::Apis::YoutubeV3::AUTH_YOUTUBE_READONLY]

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
      @logger.info('Starting authentication process...') # INFO: Start of auth
      client_secret_path = config.fetch(:client_secret_path)
      unless File.exist?(client_secret_path)
        @logger.error("Client secret file not found at: #{client_secret_path}")
        raise "Client secret file not found at: #{client_secret_path}. Please download it from Google Cloud Console and place it correctly."
      end
      client_id = Google::Auth::ClientId.from_file(client_secret_path)
      @logger.debug("Client ID loaded from: #{client_secret_path}")

      token_store_path = config.fetch(:tokens_path)
      @logger.debug("Token store path: #{token_store_path}") # DEBUG: Token store path
      FileUtils.mkdir_p(File.dirname(token_store_path))
      token_store = Google::Auth::Stores::FileTokenStore.new(file: token_store_path)

      authorizer = Google::Auth::UserAuthorizer.new(client_id, YOUTUBE_API_SCOPE, token_store)
      user_id = 'default_user'
      @logger.debug("Attempting to load existing tokens for user_id: #{user_id} from token store: #{token_store_path}") # DEBUG: Attempt load
      credentials = authorizer.get_credentials(user_id)

      if credentials.nil?
        @logger.info('No valid credentials found in token store. Initiating new OAuth flow.') # INFO: New flow
        auth_url = authorizer.get_authorization_url(base_url: OOB_URI)
        @logger.debug("OAuth flow details: App Name: #{config.fetch(:app_name, 'Ruby YouTube Uploader')}, Scope: #{YOUTUBE_API_SCOPE.join(', ')}") # DEBUG: Auth URL details
        @logger.debug("Generated authorization URL: #{auth_url}") # DEBUG: Auth URL itself

        code_input_instruction = get_authorization_instructions(auth_url: auth_url)
        @logger.info("Waiting for user to authorize and enter code. Instructions: #{code_input_instruction}") # INFO: Waiting for user
        code = if user_interaction_provider
                 user_interaction_provider.call(code_input_instruction)
               else
                 puts code_input_instruction # This is user-facing, not logged explicitly as a log message
                 STDIN.gets.chomp.strip
               end

        # DEBUG: Log received code (masked)
        @logger.debug("Authorization code received: #{code.nil? || code.empty? ? 'EMPTY' : '****** (masked)'}")

        if code.nil? || code.empty?
          @logger.error('Authentication cancelled: Authorization code not provided by user.') # ERROR: No code
          raise "Authentication cancelled or code not provided."
        end

        @logger.debug("Attempting to exchange authorization code for token...") # DEBUG: Attempt exchange
        begin
          credentials = authorizer.get_and_store_credentials_from_code(
            user_id: user_id, code: code, base_url: OOB_URI
          )
          @logger.info('Token exchange successful. Credentials received.') # INFO: Exchange success
          @logger.debug("New tokens saved to store: #{token_store_path}") # DEBUG: Saving new tokens
        rescue StandardError => e
          @logger.error("Error during token exchange: #{e.message}") # ERROR: Exchange failure
          @logger.debug("Backtrace for token exchange error: #{e.backtrace.join("\n")}")
          raise "Failed to exchange authorization code for token: #{e.message}"
        end
      else
        @logger.info('Successfully loaded existing tokens from file.') # INFO: Tokens loaded
      end

      if credentials.nil?
        # This case should ideally be caught by the specific error handling above (e.g. token exchange failure)
        @logger.error('Failed to obtain credentials after authentication process.') # ERROR: General failure
        raise "Failed to obtain credentials."
      end

      # Initialize the YouTube API service
      service = Google::Apis::YoutubeV3::YouTubeService.new
      service.client_options.application_name = config.fetch(:app_name, 'Ruby YouTube Uploader')
      service.authorization = credentials
      @service = service
      @logger.info('YouTube API service initialized and authorized successfully.')
      @service
    rescue StandardError => e
      # Log generic errors not caught by more specific handlers above
      @logger.error("An unexpected error occurred during the authentication process: #{e.message}") # ERROR: Any other error
      @logger.debug("Backtrace for unexpected authentication error: #{e.backtrace.join("\n")}")
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

      # Options for fetching playlist items
      max_results = options.fetch(:max_results, 25).to_i
      page_token = options[:page_token]

      begin
        @logger.info('Fetching YouTube channel details to find uploads playlist...')
        channel_response = @service.list_channels('contentDetails', mine: true)

        if channel_response.items.nil? || channel_response.items.empty?
          @logger.error('Could not find YouTube channel for the authenticated user.')
          return []
        end

        channel_item = channel_response.items.first
        uploads_playlist_id = nil

        if channel_item &&
           channel_item.content_details &&
           channel_item.content_details.related_playlists &&
           (playlist_id_val = channel_item.content_details.related_playlists.uploads) &&
           !playlist_id_val.empty?
          uploads_playlist_id = playlist_id_val
        end

        unless uploads_playlist_id
          @logger.error('Could not find uploads playlist ID for the user.')
          return []
        end

        @logger.info("Successfully fetched uploads playlist ID: #{uploads_playlist_id}")

        # Now, fetch items from this playlist
        @logger.info("Fetching playlist items from playlist ID: #{uploads_playlist_id} with max_results: #{max_results}, page_token: #{page_token || 'N/A'}")
        playlist_items_response = @service.list_playlist_items(
          'snippet', # Part
          playlist_id: uploads_playlist_id,
          max_results: max_results,
          page_token: page_token
        )

        if playlist_items_response.items.nil? || playlist_items_response.items.empty?
          @logger.info("No video items found in playlist: #{uploads_playlist_id}")
          return []
        end

        @logger.info("Successfully fetched #{playlist_items_response.items.count} video items from playlist: #{uploads_playlist_id}")

        video_list_items = playlist_items_response.items.map do |item|
          # Ensure snippet and resource_id are present
          unless item.snippet && item.snippet.resource_id && item.snippet.resource_id.video_id
            @logger.warn("Skipping playlist item due to missing snippet, resource_id, or video_id. Item ID: #{item.id if item}")
            next nil
          end

          video_id = item.snippet.resource_id.video_id
          title = item.snippet.title
          youtube_url = "https://www.youtube.com/watch?v=#{video_id}"

          published_at_str = item.snippet.published_at
          published_at = nil
          if published_at_str
            begin
              published_at = Time.parse(published_at_str)
            rescue ArgumentError => e
              @logger.warn("Failed to parse published_at for video ID #{video_id}: #{e.message}. Raw value: '#{published_at_str}'")
            end
          end

          # Safely access thumbnails, preferring medium, then default
          thumbnail_url = nil
          if item.snippet.thumbnails
            if item.snippet.thumbnails.medium
              thumbnail_url = item.snippet.thumbnails.medium.url
            elsif item.snippet.thumbnails.default
              thumbnail_url = item.snippet.thumbnails.default.url
            end
          end

          Entities::VideoListItem.new(
            id: video_id,
            title: title,
            youtube_url: youtube_url,
            published_at: published_at,
            thumbnail_url: thumbnail_url
          )
        end.compact # Remove any nil items that were skipped

        @logger.info("Mapped #{video_list_items.count} items to VideoListItem entities.")
        return video_list_items

      rescue Google::Apis::ClientError => e
        @logger.error("Google API Client Error while fetching channel details or playlist items: #{e.message}")
        # Depending on desired behavior, could return empty array or re-raise
        return [] # Return empty for now on client errors
      rescue Google::Apis::AuthorizationError => e
        @logger.error("Google API Authorization Error while fetching channel details or playlist items: #{e.message}")
        raise # Re-raise auth errors as they are critical
      rescue StandardError => e
        @logger.error("An unexpected error occurred while fetching channel details or playlist items: #{e.message}")
        # Optionally log backtrace: @logger.debug(e.backtrace.join("\n"))
        return [] # Return empty for other unexpected errors
      end
    end

    # Uploads a video to YouTube.
    #
    # @param video_details [Entities::VideoDetails] An object containing all necessary video metadata.
    # @return [Google::Apis::YoutubeV3::Video] The uploaded video object from YouTube API.
    # @raise [AuthenticationError] if the service is not authenticated.
    # @raise [ArgumentError] if the video file does not exist.
    # @raise [YouTubeUploadError] if the API upload fails.
    # @raise [StandardError] for other unexpected issues.
    def upload_video(video_details:)
      @logger.info("Starting video upload for: '#{video_details.title}'")
      @logger.debug("Video details being used for upload: #{video_details.inspect}")

      unless @service && @service.authorization && @service.authorization.access_token
        msg = 'Authentication required before uploading video. Service not initialized or not authorized.'
        @logger.error(msg)
        raise AuthenticationError, msg
      end

      unless File.exist?(video_details.file_path)
        msg = "Video file not found at path: #{video_details.file_path}"
        @logger.error(msg)
        raise ArgumentError, msg # Or IOError
      end

      video_object = Google::Apis::YoutubeV3::Video.new(
        snippet: {
          title: video_details.title,
          description: video_details.description,
          tags: video_details.tags,
          category_id: video_details.category_id.to_s # Ensure category_id is a string
        },
        status: {
          privacy_status: video_details.privacy_status
        }
      )
      @logger.debug("Constructed Google::Apis::YoutubeV3::Video object: #{video_object.to_json}")

      begin
        # Note: Starting log was moved up. Re-logging file_path here for clarity during actual upload step.
        @logger.debug("Initiating upload of file: #{video_details.file_path} to YouTube.")
        content_type = 'application/octet-stream' # Generic content type
        @logger.debug("Uploading with content_type: #{content_type}")

        response = @service.insert_video(
          'snippet,status', # Parts to include in the API response
          video_object,
          upload_source: video_details.file_path,
          content_type: content_type,
          options: {
            # authorization: @service.authorization # Already set on @service instance
          }
        )

        @logger.info("Video uploaded successfully. ID: #{response.id}")
        @logger.debug("Full API response for successful upload: #{response.to_json}")
        response # Return the full video object from YouTube
      rescue Google::Apis::ClientError => e
        error_message = "Failed to upload video: Google API Client Error. Status: #{e.status_code}, Message: #{e.message}"
        error_message += " Body: #{e.body}" if e.respond_to?(:body) && e.body
        @logger.error(error_message)
        @logger.debug("ClientError Headers: #{e.header}") if e.respond_to?(:header)
        @logger.debug("ClientError Backtrace: #{e.backtrace.join("\n")}")
        raise YouTubeUploadError, error_message
      rescue Google::Apis::AuthorizationError => e
        error_message = "Failed to upload video: Google API Authorization Error. Message: #{e.message}"
        @logger.error(error_message)
        @logger.debug("AuthorizationError Backtrace: #{e.backtrace.join("\n")}")
        # This might indicate expired or revoked credentials.
        raise YouTubeUploadError, error_message # Could also be AuthenticationError if more specific
      rescue StandardError => e
        error_message = "Failed to upload video: An unexpected error occurred. Type: #{e.class}, Message: #{e.message}"
        @logger.error(error_message)
        @logger.debug("Unexpected Error Backtrace: #{e.backtrace.join("\n")}")
        raise YouTubeUploadError, error_message # Or re-raise e if appropriate
      end
    end

    # exchange_code_for_tokens is effectively handled within the #authenticate method's flow
    # when credentials are nil. No separate public method is needed from the gateway interface here.
  end
end
