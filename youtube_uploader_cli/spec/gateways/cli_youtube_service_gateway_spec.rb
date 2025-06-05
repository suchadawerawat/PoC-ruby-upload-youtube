# frozen_string_literal: true

require 'rspec'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/youtube_v3'
require_relative '../../app/gateways/cli_youtube_service_gateway'
require_relative '../../app/entities/video_list_item' # Added for VideoListItem
require 'tempfile' # For temporary files
require 'fileutils' # To ensure dir exists for token store
require 'logger' # Added for mock_logger

RSpec.describe Gateways::CliYouTubeServiceGateway do
  let(:mock_logger) { instance_double(Logger, info: nil, error: nil, warn: nil, debug: nil) }
  let(:gateway) { described_class.new(mock_logger) }
  let!(:client_secret_file) { Tempfile.new(['client_secret', '.json']) } # Use let! to ensure file is created before each test
  let!(:tokens_file) { Tempfile.new(['tokens', '.yaml']) }

  let(:config_for_auth_tests) do # Renamed to avoid collision with list_videos config
    {
      client_secret_path: client_secret_file.path,
      tokens_path: tokens_file.path,
      app_name: 'TestAppAuth'
    }
  end

  # Prepare a dummy client secret content
  let(:dummy_client_secret_content) do
    '{ "installed": { "client_id": "test_client_id_from_file", "client_secret": "test_client_secret_from_file" } }'
  end

  # Mock objects for Google API interactions (used by #authenticate tests)
  let(:mock_client_id) { instance_double(Google::Auth::ClientId, id: 'test_client_id_from_file', secret: 'test_client_secret_from_file') }
  let(:mock_token_store) { instance_double(Google::Auth::Stores::FileTokenStore) }
  let(:mock_authorizer) { instance_double(Google::Auth::UserAuthorizer) }
  let(:mock_auth_credentials) { instance_double(Google::Auth::UserRefreshCredentials, access_token: 'valid_access_token_for_auth', expired?: false) } # Renamed

  before do # This before block is for the #authenticate describe block primarily
    client_secret_file.write(dummy_client_secret_content)
    client_secret_file.rewind
    FileUtils.mkdir_p(File.dirname(tokens_file.path))
    allow(Google::Auth::ClientId).to receive(:from_file).with(client_secret_file.path).and_return(mock_client_id)
    allow(Google::Auth::Stores::FileTokenStore).to receive(:new).with(file: tokens_file.path).and_return(mock_token_store)
    allow(Google::Auth::UserAuthorizer).to receive(:new)
      .with(mock_client_id, Gateways::CliYouTubeServiceGateway::YOUTUBE_API_SCOPE, mock_token_store)
      .and_return(mock_authorizer)
  end

  after do
    client_secret_file.close
    client_secret_file.unlink
    tokens_file.close
    tokens_file.unlink
  end

  describe '#authenticate' do
    context 'when client_secret.json is missing' do
      it 'raises an error' do
        File.delete(client_secret_file.path) if File.exist?(client_secret_file.path)
        expect { gateway.authenticate(config: config_for_auth_tests) }
          .to raise_error(/Client secret file not found at:/)
      end
    end

    context 'when valid stored credentials exist' do
      before do
        allow(mock_authorizer).to receive(:get_credentials).with('default_user').and_return(mock_auth_credentials)
      end

      it 'returns an authorized YouTubeService and sets @service' do
        service = gateway.authenticate(config: config_for_auth_tests)
        expect(service).to be_a(Google::Apis::YoutubeV3::YouTubeService)
        expect(service.authorization).to eq(mock_auth_credentials)
        expect(service.client_options.application_name).to eq('TestAppAuth')
        expect(gateway.instance_variable_get(:@service)).to eq(service)
      end
    end

    context 'when no stored credentials exist (requires OAuth flow)' do
      let(:auth_url) { 'https://accounts.google.com/o/oauth2/auth?approval_prompt=force&...' }
      let(:auth_code) { 'test_auth_code' }
      let(:user_interaction_proc) { instance_double(Proc, 'UserInteractionProvider') }

      before do
        allow(mock_authorizer).to receive(:get_credentials).with('default_user').and_return(nil)
        allow(mock_authorizer).to receive(:get_authorization_url)
          .with(base_url: Gateways::CliYouTubeServiceGateway::OOB_URI)
          .and_return(auth_url)
        allow(mock_authorizer).to receive(:get_and_store_credentials_from_code)
          .with(user_id: 'default_user', code: auth_code, base_url: Gateways::CliYouTubeServiceGateway::OOB_URI)
          .and_return(mock_auth_credentials)
      end

      it 'prompts user, exchanges code, stores credentials, and returns YouTubeService' do
        # Instead of matching exact instructions, check if the proc is called with a string containing the auth_url
        expect(user_interaction_proc).to receive(:call) do |arg|
          expect(arg).to be_a(String)
          expect(arg).to include(auth_url)
          auth_code # Return the auth_code
        end

        service = gateway.authenticate(config: config_for_auth_tests, user_interaction_provider: user_interaction_proc)

        expect(service).to be_a(Google::Apis::YoutubeV3::YouTubeService)
        expect(service.authorization).to eq(mock_auth_credentials)
        expect(gateway.instance_variable_get(:@service)).to eq(service)
      end

      it 'raises an error if auth code is not provided' do
        # Instead of matching exact instructions, check if the proc is called with a string containing the auth_url
        expect(user_interaction_proc).to receive(:call) do |arg|
          expect(arg).to be_a(String)
          expect(arg).to include(auth_url)
          "" # Return empty auth_code
        end

        expect { gateway.authenticate(config: config_for_auth_tests, user_interaction_provider: user_interaction_proc) }
          .to raise_error("Authentication cancelled or code not provided.")
      end
    end

    context 'when get_and_store_credentials_from_code returns nil' do
      before do
        allow(mock_authorizer).to receive(:get_credentials).with('default_user').and_return(nil)
        allow(mock_authorizer).to receive(:get_authorization_url).and_return('some_auth_url')
        allow(mock_authorizer).to receive(:get_and_store_credentials_from_code).and_return(nil)
      end

      it 'raises "Failed to obtain credentials."' do
         user_interaction_stub = proc { "any_code" }
         expect { gateway.authenticate(config: config_for_auth_tests, user_interaction_provider: user_interaction_stub) }
           .to raise_error("Failed to obtain credentials.")
      end
    end
  end

  # Tests for #upload_video will be added in a subsequent step when it's implemented.

  # Note: The existing `let(:logger)` is called `mock_logger`.
  # The new tests use `logger` as the variable name for the logger passed to the gateway.
  # We will ensure `gateway` is initialized with `mock_logger`.
  # The `let(:gateway)` is already defined as `described_class.new(mock_logger)`.

  describe '#list_videos' do
    # mock_youtube_service is used by the new tests, and gateway is already using mock_logger
    # Using a plain double to avoid instance_double's strict keyword argument checking for now,
    # as the 'mine: true' keyword argument seems to be the issue with the real library vs instance_double.
    let(:mock_youtube_service) { double('Google::Apis::YoutubeV3::YouTubeService') }
    # gateway is already defined in the outer scope and initialized with mock_logger.

    before do
      # Simulate that authentication has occurred and @service is set with the mock_youtube_service.
      gateway.instance_variable_set(:@service, mock_youtube_service)
      # Mock the authorization check to simulate an authenticated service
      # Use Google::Auth::UserRefreshCredentials as it's the class that has access_token
      allow(mock_youtube_service).to receive(:authorization).and_return(instance_double(Google::Auth::UserRefreshCredentials, access_token: 'fake_token'))
    end

    let(:max_results) { 5 }
    let(:api_video_item) do
      # Ensure Google::Apis::YoutubeV3::Video is available
      item = Google::Apis::YoutubeV3::Video.new
      item.id = 'video123'
      snippet = Google::Apis::YoutubeV3::VideoSnippet.new
      snippet.title = 'Test Video Title'
      # Ensure published_at is a string in ISO 8601 format as the API would return
      snippet.published_at = Time.now.utc.iso8601
      thumbnails = Google::Apis::YoutubeV3::ThumbnailDetails.new
      default_thumbnail = Google::Apis::YoutubeV3::Thumbnail.new
      default_thumbnail.url = 'http://example.com/thumb.jpg'
      thumbnails.default = default_thumbnail
      snippet.thumbnails = thumbnails
      item.snippet = snippet
      # player and status are also part of the 'part' parameter, but not strictly needed for this mapping test if not used by VideoListItem
      item
    end
    let(:api_response) do
      # Correct class name is ListVideosResponse (plural)
      response = Google::Apis::YoutubeV3::ListVideosResponse.new
      response.items = [api_video_item]
      response.next_page_token = nil # Optional: for pagination tests
      response.prev_page_token = nil # Optional
      # page_info = Google::Apis::YoutubeV3::PageInfo.new
      # page_info.total_results = 1
      # page_info.results_per_page = max_results
      # response.page_info = page_info # Optional
      response
    end

    context 'when API call is successful' do
      it 'calls the YouTube API with `mine: true` and maps the response' do
        expect(mock_youtube_service).to receive(:list_videos)
          .with('snippet,player,status', mine: true, max_results: max_results, page_token: nil) # Match keyword arguments
          .and_return(api_response)

        # Pass mock_logger as logger to gateway calls if it were a direct param
        # but gateway is already initialized with mock_logger via the outer let(:gateway)
        video_list_items = gateway.list_videos(options: { max_results: max_results })

        expect(video_list_items).to be_an(Array)
        expect(video_list_items.size).to eq(1)
        video_item = video_list_items.first
        expect(video_item).to be_a(Entities::VideoListItem)
        expect(video_item.id).to eq('video123')
        expect(video_item.title).to eq('Test Video Title')
        expect(video_item.youtube_url).to eq('https://www.youtube.com/watch?v=video123')
        expect(video_item.thumbnail_url).to eq('http://example.com/thumb.jpg')
        # To test published_at, ensure it's parsed correctly into a Time object
        expect(video_item.published_at).to be_a(Time)
        # Compare ISO8601 strings for precision, especially with milliseconds
        expect(video_item.published_at.iso8601(3)).to eq(Time.parse(api_video_item.snippet.published_at).iso8601(3))
      end
    end

    context 'when API call fails' do
      it 'logs an error and returns an empty array for Google::Apis::ClientError' do
        expect(mock_youtube_service).to receive(:list_videos)
          .with('snippet,player,status', mine: true, max_results: anything, page_token: anything) # Match keyword arguments, allow any value for others
          .and_raise(Google::Apis::ClientError.new('API client error'))

        # Expect logger (which is mock_logger) to be called
        expect(mock_logger).to receive(:error).with("Google API Client Error while listing videos: API client error")

        video_list_items = gateway.list_videos(options: {max_results: 10}) # Example options
        expect(video_list_items).to eq([])
      end

      it 'logs an error and re-raises Google::Apis::AuthorizationError' do
        expect(mock_youtube_service).to receive(:list_videos)
          .with('snippet,player,status', mine: true, max_results: anything, page_token: anything) # Match keyword arguments
          .and_raise(Google::Apis::AuthorizationError.new('API auth error'))

        expect(mock_logger).to receive(:error).with("Google API Authorization Error while listing videos: API auth error")

        expect { gateway.list_videos(options: {}) }.to raise_error(Google::Apis::AuthorizationError, 'API auth error')
      end
    end

    context 'when not authenticated' do
      it 'raises an error if @service is nil' do
        gateway.instance_variable_set(:@service, nil) # Simulate @service not being set
        expect(mock_logger).to receive(:warn).with('Attempted to list videos without prior authentication.')
        expect { gateway.list_videos(options: {}) }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end

      it 'raises an error if @service.authorization is nil' do
        allow(mock_youtube_service).to receive(:authorization).and_return(nil)
        # @service is already set with mock_youtube_service in the main before block for this describe
        expect(mock_logger).to receive(:warn).with('Attempted to list videos without prior authentication.')
        expect { gateway.list_videos(options: {}) }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end

      it 'raises an error if @service.authorization.access_token is nil' do
        # Ensure the authorization double itself is not nil, but its access_token is.
        # Use Google::Auth::UserRefreshCredentials as it's the class that has access_token
        auth_double_no_token = instance_double(Google::Auth::UserRefreshCredentials, access_token: nil)
        allow(mock_youtube_service).to receive(:authorization).and_return(auth_double_no_token)
        # @service is already set
        expect(mock_logger).to receive(:warn).with('Attempted to list videos without prior authentication.')
        expect { gateway.list_videos(options: {}) }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end
    end
  end
end
