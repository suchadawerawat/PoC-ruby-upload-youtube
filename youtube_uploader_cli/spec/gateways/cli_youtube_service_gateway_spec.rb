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

  describe '#list_videos' do
    let(:mock_youtube_service) { double('Google::Apis::YoutubeV3::YouTubeService') } # Changed from instance_double
    # Changed mock_credentials to avoid conflict with the one in #authenticate tests
    let(:mock_list_video_credentials) { instance_double(Google::Auth::UserRefreshCredentials, access_token: 'fake_list_video_token') }
    # gateway is already defined in the outer scope
    # let(:gateway) { described_class.new } # This would create a new instance, not using the one from outer scope

    # Configuration for list_videos specific setup, if needed for fixture files
    let(:fixture_client_secret_path) { 'spec/fixtures/fake_client_secret.json' }
    let(:fixture_tokens_path) { 'spec/fixtures/fake_tokens.yaml' }

    before do
      # Create dummy fixture files for list_videos tests
      # These are used to simulate a state where @service could have been populated by a prior auth call
      # that used these paths.
      FileUtils.mkdir_p('spec/fixtures')
      File.write(fixture_client_secret_path, '{ "installed": { "client_id": "test_client_id_fixture", "client_secret": "test_client_secret_fixture" } }')
      File.write(fixture_tokens_path, "---
default_user: !ruby/object:Google::Auth::UserRefreshCredentials
  access_token: fake_access_token_fixture
  client_id: test_client_id_fixture
  client_secret: test_client_secret_fixture
  refresh_token: fake_refresh_token_fixture
  scope: https://www.googleapis.com/auth/youtube.upload
  expiration_time_millis: #{(Time.now.to_i + 3600) * 1000}
")
      # Set the @service instance variable with a mock for list_videos tests
      # This simulates that authenticate was called successfully and @service is set.
      allow(mock_youtube_service).to receive(:authorization).and_return(mock_list_video_credentials)
      gateway.instance_variable_set(:@service, mock_youtube_service)
    end

    after do
      # Clean up fixture files created for list_videos tests
      FileUtils.rm_f(fixture_client_secret_path)
      FileUtils.rm_f(fixture_tokens_path)
      FileUtils.rm_rf('spec/fixtures') if Dir.exist?('spec/fixtures') && Dir.empty?('spec/fixtures')
    end

    context 'when authentication is missing (no @service)' do
      it 'raises an error' do
        gateway.instance_variable_set(:@service, nil) # Simulate service not being set
        expect { gateway.list_videos }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end
    end

    context 'when @service is present but authorization is missing' do
      it 'raises an error' do
        allow(mock_youtube_service).to receive(:authorization).and_return(nil)
        gateway.instance_variable_set(:@service, mock_youtube_service)
        expect { gateway.list_videos }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end
    end

    context 'when @service is present but access_token is missing' do
      it 'raises an error' do
        allow(mock_list_video_credentials).to receive(:access_token).and_return(nil) # mock_list_video_credentials is used here
        allow(mock_youtube_service).to receive(:authorization).and_return(mock_list_video_credentials)
        gateway.instance_variable_set(:@service, mock_youtube_service)
        expect { gateway.list_videos }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end
    end

    context 'when API call is successful' do
      let(:api_response_item1) do
        double('Google::Apis::YoutubeV3::Video',
               id: 'id1',
               snippet: double('Google::Apis::YoutubeV3::VideoSnippet',
                               title: 'Video Title 1',
                               published_at: '2023-01-01T12:00:00Z',
                               thumbnails: double('Google::Apis::YoutubeV3::ThumbnailDetails', default: double('thumbnail', url: 'http://thumb1.jpg'))),
               player: double('Google::Apis::YoutubeV3::VideoPlayer', embed_html: '<iframe...id1>'),
               status: double('Google::Apis::YoutubeV3::VideoStatus', privacy_status: 'public')
              )
      end
      let(:api_response_item2) do
        double('Google::Apis::YoutubeV3::Video',
               id: 'id2',
               snippet: double('Google::Apis::YoutubeV3::VideoSnippet',
                               title: 'Video Title 2',
                               published_at: '2023-01-02T12:00:00Z',
                               thumbnails: double('Google::Apis::YoutubeV3::ThumbnailDetails', default: double('thumbnail', url: 'http://thumb2.jpg'))),
               player: double('Google::Apis::YoutubeV3::VideoPlayer', embed_html: '<iframe...id2>'),
               status: double('Google::Apis::YoutubeV3::VideoStatus', privacy_status: 'private')
              )
      end
      let(:api_response) { double('Google::Apis::YoutubeV3::ListVideoResponse', items: [api_response_item1, api_response_item2], next_page_token: nil) }

      it 'calls the YouTube API with correct parameters and maps response' do
        expected_parts = 'snippet,player,status'
        # Default max_results in implementation is 25, but test is for 10

        expect(mock_youtube_service).to receive(:list_videos) do |part, opts|
          expect(part).to eq(expected_parts)
          expect(opts).to include(max_results: 10)
          expect(opts).not_to include(:my_videos) # Check that :my_videos is not present
          expect(opts).not_to include(:mine) # Explicitly check for :mine as well
          api_response # return value
        end

        videos = gateway.list_videos(options: { max_results: 10 })

        expect(videos.size).to eq(2)
        expect(videos.first).to be_an_instance_of(Entities::VideoListItem)
        expect(videos.first.id).to eq('id1')
        expect(videos.first.title).to eq('Video Title 1')
        expect(videos.first.youtube_url).to eq('https://www.youtube.com/watch?v=id1')
        expect(videos.first.published_at).to eq(Time.parse('2023-01-01T12:00:00Z'))
        expect(videos.first.thumbnail_url).to eq('http://thumb1.jpg')
      end

      it 'uses provided max_results (implementation default is 25) and page_token' do
        expect(mock_youtube_service).to receive(:list_videos) do |part, opts|
          expect(part).to eq('snippet,player,status')
          expect(opts).to include(max_results: 5, page_token: 'nextPage123')
          expect(opts).not_to include(:my_videos)
          expect(opts).not_to include(:mine)
          double('Google::Apis::YoutubeV3::ListVideoResponse', items: [], next_page_token: nil) # return value
        end

        gateway.list_videos(options: { max_results: 5, page_token: 'nextPage123' })
      end

      it 'uses default max_results of 25 if not provided' do
        expect(mock_youtube_service).to receive(:list_videos) do |part, opts|
          expect(part).to eq('snippet,player,status')
          expect(opts).to include(max_results: 25)
          expect(opts).not_to include(:my_videos)
          expect(opts).not_to include(:mine)
          expect(opts).to include(page_token: nil) # page_token should be present and nil
          double('Google::Apis::YoutubeV3::ListVideoResponse', items: [], next_page_token: nil) # return value
        end
        gateway.list_videos(options: {}) # No max_results here
      end


      it 'returns an empty array if API returns no items' do
        empty_response = double('Google::Apis::YoutubeV3::ListVideoResponse', items: [], next_page_token: nil)
        allow(mock_youtube_service).to receive(:list_videos).and_return(empty_response)

        videos = gateway.list_videos
        expect(videos).to be_empty
      end

      it 'returns an empty array if API returns nil items' do
        nil_items_response = double('Google::Apis::YoutubeV3::ListVideoResponse', items: nil, next_page_token: nil)
        allow(mock_youtube_service).to receive(:list_videos).and_return(nil_items_response)

        videos = gateway.list_videos
        expect(videos).to be_empty
      end
    end

    context 'when API call fails' do
      it 'handles Google::Apis::ClientError and returns empty array' do
        allow(mock_youtube_service).to receive(:list_videos) # Changed to allow for logger expectation
          .and_raise(Google::Apis::ClientError.new('client error'))
        expect(mock_logger).to receive(:error).with("Google API Client Error while listing videos: client error")
        expect(gateway.list_videos).to be_empty
      end

      it 're-raises Google::Apis::AuthorizationError' do
        allow(mock_youtube_service).to receive(:list_videos) # Changed to allow for logger expectation
          .and_raise(Google::Apis::AuthorizationError.new('auth error'))
        expect(mock_logger).to receive(:error).with("Google API Authorization Error while listing videos: auth error")
        expect { gateway.list_videos }.to raise_error(Google::Apis::AuthorizationError, 'auth error')
      end

      it 'handles other StandardError and returns empty array' do
        allow(mock_youtube_service).to receive(:list_videos) # Changed to allow for logger expectation
          .and_raise(StandardError.new('unexpected error'))
        expect(mock_logger).to receive(:error).with("An unexpected error occurred while listing videos: unexpected error")
        expect(gateway.list_videos).to be_empty
      end
    end
  end
end
