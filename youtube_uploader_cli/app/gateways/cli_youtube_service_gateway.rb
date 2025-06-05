# frozen_string_literal: true

require 'googleauth' # For user authorization
require 'googleauth/stores/file_token_store' # For storing user credentials
require 'google/apis/youtube_v3' # The YouTube API client
require 'fileutils' # For ensuring directory for token store exists
require_relative './youtube_service_gateway'
require_relative '../entities/video_details' # Though not directly used in auth, good for consistency


module Gateways
  # Concrete implementation of YouTubeServiceGateway for a CLI environment.
  # Handles OAuth 2.0 authentication and video uploads using the google-api-client.
  class CliYouTubeServiceGateway
    include YouTubeServiceGateway # Includes the interface methods and default get_authorization_instructions

    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob' # Out-of-band URI for desktop apps
    YOUTUBE_API_SCOPE = Google::Apis::YoutubeV3::AUTH_YOUTUBE_UPLOAD

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
      client_secret_path = config.fetch(:client_secret_path)
      unless File.exist?(client_secret_path)
        raise "Client secret file not found at: #{client_secret_path}. Please download it from Google Cloud Console and place it correctly."
      end
      client_id = Google::Auth::ClientId.from_file(client_secret_path)

      token_store_path = config.fetch(:tokens_path)
      FileUtils.mkdir_p(File.dirname(token_store_path)) # Ensure directory exists
      token_store = Google::Auth::Stores::FileTokenStore.new(file: token_store_path)

      authorizer = Google::Auth::UserAuthorizer.new(client_id, YOUTUBE_API_SCOPE, token_store)
      user_id = 'default_user' # For CLI, we usually have one user per token store

      credentials = authorizer.get_credentials(user_id)

      if credentials.nil?
        auth_url = authorizer.get_authorization_url(base_url: OOB_URI)

        # Use the provided interaction provider or default to STDIN
        code_input_instruction = get_authorization_instructions(auth_url: auth_url) # Uses method from included module
        code = if user_interaction_provider
                 user_interaction_provider.call(code_input_instruction)
               else
                 puts code_input_instruction
                 STDIN.gets.chomp.strip # Make sure to strip whitespace
               end

        raise "Authentication cancelled or code not provided." if code.nil? || code.empty?

        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id, code: code, base_url: OOB_URI
        )
      end

      raise "Failed to obtain credentials." if credentials.nil?

      # Initialize the YouTube API service
      service = Google::Apis::YoutubeV3::YouTubeService.new
      service.client_options.application_name = config.fetch(:app_name, 'Ruby YouTube Uploader')
      service.authorization = credentials
      service
    end

    # upload_video will be implemented in a later subtask
    # def upload_video(video_data:)
    #   raise NotImplementedError, "upload_video is not yet implemented in CliYouTubeServiceGateway"
    # end

    # exchange_code_for_tokens is effectively handled within the #authenticate method's flow
    # when credentials are nil. No separate public method is needed from the gateway interface here.
  end
end
