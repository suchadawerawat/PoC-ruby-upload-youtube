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
    # Using instance_double to ensure method signatures are respected.
    let(:mock_youtube_service) { instance_double(Google::Apis::YoutubeV3::YouTubeService) }
    let(:max_results_option) { 10 }
    let(:page_token_option) { 'nextPageToken123' }
    let(:options) { { max_results: max_results_option, page_token: page_token_option } }

    # Mock data for list_channels call
    let(:mock_uploads_playlist_id) { 'UUxxxxxxxxx_uploads_playlist_id' }
    let(:channel_item) do
      channel = Google::Apis::YoutubeV3::Channel.new
      content_details = Google::Apis::YoutubeV3::ChannelContentDetails.new
      related_playlists = Google::Apis::YoutubeV3::ChannelContentDetails::RelatedPlaylists.new
      related_playlists.uploads = mock_uploads_playlist_id
      content_details.related_playlists = related_playlists
      channel.content_details = content_details
      channel.id = 'channel123' # Add an ID for completeness
      channel
    end
    let(:channel_response) do
      response = Google::Apis::YoutubeV3::ListChannelsResponse.new # Corrected: ListChannelsResponse
      response.items = [channel_item]
      response
    end
    let(:empty_channel_response) do
      Google::Apis::YoutubeV3::ListChannelsResponse.new.tap { |r| r.items = [] } # Corrected: ListChannelsResponse
    end
    let(:channel_response_no_uploads_id) do
      channel_no_id = Google::Apis::YoutubeV3::Channel.new
      content_details_no_id = Google::Apis::YoutubeV3::ChannelContentDetails.new
      related_playlists_no_id = Google::Apis::YoutubeV3::ChannelContentDetails::RelatedPlaylists.new
      # uploads_id is intentionally nil or empty
      content_details_no_id.related_playlists = related_playlists_no_id
      channel_no_id.content_details = content_details_no_id
      Google::Apis::YoutubeV3::ListChannelsResponse.new.tap { |r| r.items = [channel_no_id] } # Corrected: ListChannelsResponse
    end

    # Mock data for list_playlist_items call
    let(:playlist_item1_video_id) { 'video123' }
    let(:playlist_item1_title) { 'Test Playlist Video 1' }
    let(:playlist_item1_published_at_str) { '2023-01-01T12:00:00Z' }
    let(:playlist_item1_published_at_time) { Time.parse(playlist_item1_published_at_str) }
    let(:playlist_item1_thumb_url) { 'http://example.com/medium_thumb1.jpg' }

    let(:playlist_item1) do
      item = Google::Apis::YoutubeV3::PlaylistItem.new
      item.id = 'p_item_1' # Playlist item ID
      snippet = Google::Apis::YoutubeV3::PlaylistItemSnippet.new
      snippet.title = playlist_item1_title
      snippet.published_at = playlist_item1_published_at_str
      resource_id = Google::Apis::YoutubeV3::ResourceId.new
      resource_id.video_id = playlist_item1_video_id
      resource_id.kind = 'youtube#video'
      snippet.resource_id = resource_id
      thumbnails = Google::Apis::YoutubeV3::ThumbnailDetails.new
      medium_thumbnail = Google::Apis::YoutubeV3::Thumbnail.new
      medium_thumbnail.url = playlist_item1_thumb_url
      thumbnails.medium = medium_thumbnail
      snippet.thumbnails = thumbnails
      item.snippet = snippet
      item
    end

    let(:playlist_item_malformed_video_id) do
        item = Google::Apis::YoutubeV3::PlaylistItem.new
        item.id = 'p_item_malformed'
        snippet = Google::Apis::YoutubeV3::PlaylistItemSnippet.new
        snippet.title = "Malformed Video ID Item"
        # snippet.resource_id is missing or resource_id.video_id is missing
        item.snippet = snippet
        item
    end

    let(:playlist_item_unparseable_date) do
        item = Google::Apis::YoutubeV3::PlaylistItem.new
        item.id = 'p_item_bad_date'
        snippet = Google::Apis::YoutubeV3::PlaylistItemSnippet.new
        snippet.title = "Unparseable Date Item"
        snippet.published_at = "Definitely not a date"
        resource_id = Google::Apis::YoutubeV3::ResourceId.new; resource_id.video_id = "video_baddate"; snippet.resource_id = resource_id
        snippet.thumbnails = Google::Apis::YoutubeV3::ThumbnailDetails.new # Add empty thumbnails to avoid nil errors there
        item.snippet = snippet
        item
    end

    let(:playlist_items_response) do
      response = Google::Apis::YoutubeV3::ListPlaylistItemsResponse.new # Corrected: ListPlaylistItemsResponse
      response.items = [playlist_item1]
      response
    end
    let(:empty_playlist_items_response) do
      Google::Apis::YoutubeV3::ListPlaylistItemsResponse.new.tap { |r| r.items = [] } # Corrected: ListPlaylistItemsResponse
    end

    before do
      gateway.instance_variable_set(:@service, mock_youtube_service)
      allow(mock_youtube_service).to receive(:authorization).and_return(instance_double(Google::Auth::UserRefreshCredentials, access_token: 'fake_token'))
    end

    context 'when authentication is missing' do
      # These tests from the previous version are still valid.
      # To make them fully independent, we ensure @service is nilled correctly for each.
      it 'raises an error if @service is nil' do
        gateway.instance_variable_set(:@service, nil)
        expect(mock_logger).to receive(:warn).with('Attempted to list videos without prior authentication.')
        expect { gateway.list_videos }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end

      it 'raises an error if @service.authorization is nil' do
        allow(mock_youtube_service).to receive(:authorization).and_return(nil)
        expect(mock_logger).to receive(:warn).with('Attempted to list videos without prior authentication.')
        expect { gateway.list_videos }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end

      it 'raises an error if @service.authorization.access_token is nil' do
        auth_double_no_token = instance_double(Google::Auth::UserRefreshCredentials, access_token: nil)
        allow(mock_youtube_service).to receive(:authorization).and_return(auth_double_no_token)
        expect(mock_logger).to receive(:warn).with('Attempted to list videos without prior authentication.')
        expect { gateway.list_videos }.to raise_error('Authentication required before listing videos. Please run the auth command.')
      end
    end

    context 'when fetching channel details fails or returns no valid data' do
      it 'logs an error and returns empty if list_channels returns no items' do
        expect(mock_youtube_service).to receive(:list_channels)
          .with('contentDetails', mine: true)
          .and_return(empty_channel_response)
        expect(mock_logger).to receive(:error).with('Could not find YouTube channel for the authenticated user.')
        expect(gateway.list_videos(options: options)).to eq([])
      end

      it 'logs an error and returns empty if uploads_playlist_id is not found' do
        expect(mock_youtube_service).to receive(:list_channels)
          .with('contentDetails', mine: true)
          .and_return(channel_response_no_uploads_id) # Response where uploads ID is missing
        expect(mock_logger).to receive(:error).with('Could not find uploads playlist ID for the user.')
        expect(gateway.list_videos(options: options)).to eq([])
      end

      it 'handles ClientError from list_channels and returns empty' do
        expect(mock_youtube_service).to receive(:list_channels)
          .with('contentDetails', mine: true)
          .and_raise(Google::Apis::ClientError.new('Channel API error'))
        expect(mock_logger).to receive(:error).with('Google API Client Error while fetching channel details or playlist items: Channel API error')
        expect(gateway.list_videos(options: options)).to eq([])
      end

      it 're-raises AuthorizationError from list_channels' do
        expect(mock_youtube_service).to receive(:list_channels)
          .with('contentDetails', mine: true)
          .and_raise(Google::Apis::AuthorizationError.new('Channel Auth error'))
        expect(mock_logger).to receive(:error).with('Google API Authorization Error while fetching channel details or playlist items: Channel Auth error')
        expect { gateway.list_videos(options: options) }.to raise_error(Google::Apis::AuthorizationError, 'Channel Auth error')
      end
    end

    context 'when fetching playlist items fails or returns no items' do
      before do # Common setup: list_channels succeeds
        allow(mock_youtube_service).to receive(:list_channels)
          .with('contentDetails', mine: true)
          .and_return(channel_response)
      end

      it 'logs a message and returns empty if list_playlist_items returns no items' do
        expect(mock_youtube_service).to receive(:list_playlist_items)
          .with('snippet', playlist_id: mock_uploads_playlist_id, max_results: max_results_option, page_token: page_token_option)
          .and_return(empty_playlist_items_response)
        expect(mock_logger).to receive(:info).with("No video items found in playlist: #{mock_uploads_playlist_id}")
        expect(gateway.list_videos(options: options)).to eq([])
      end

      it 'handles ClientError from list_playlist_items and returns empty' do
        expect(mock_youtube_service).to receive(:list_playlist_items)
          .with('snippet', playlist_id: mock_uploads_playlist_id, max_results: max_results_option, page_token: page_token_option)
          .and_raise(Google::Apis::ClientError.new('Playlist API error'))
        expect(mock_logger).to receive(:error).with('Google API Client Error while fetching channel details or playlist items: Playlist API error')
        expect(gateway.list_videos(options: options)).to eq([])
      end

      it 're-raises AuthorizationError from list_playlist_items' do
        expect(mock_youtube_service).to receive(:list_playlist_items)
          .with('snippet', playlist_id: mock_uploads_playlist_id, max_results: max_results_option, page_token: page_token_option)
          .and_raise(Google::Apis::AuthorizationError.new('Playlist Auth error'))
        expect(mock_logger).to receive(:error).with('Google API Authorization Error while fetching channel details or playlist items: Playlist Auth error')
        expect { gateway.list_videos(options: options) }.to raise_error(Google::Apis::AuthorizationError, 'Playlist Auth error')
      end
    end

    context 'when API calls are successful and items are mapped' do
      before do
        allow(mock_youtube_service).to receive(:list_channels)
          .with('contentDetails', mine: true)
          .and_return(channel_response)
        allow(mock_youtube_service).to receive(:list_playlist_items)
          .with('snippet', playlist_id: mock_uploads_playlist_id, max_results: max_results_option, page_token: page_token_option)
          .and_return(playlist_items_response) # Contains playlist_item1
      end

      it 'maps playlist items to VideoListItem entities' do
        video_list_items = gateway.list_videos(options: options)
        expect(video_list_items).to be_an(Array)
        expect(video_list_items.size).to eq(1)

        mapped_item = video_list_items.first
        expect(mapped_item).to be_a(Entities::VideoListItem)
        expect(mapped_item.id).to eq(playlist_item1_video_id)
        expect(mapped_item.title).to eq(playlist_item1_title)
        expect(mapped_item.youtube_url).to eq("https://www.youtube.com/watch?v=#{playlist_item1_video_id}")
        expect(mapped_item.published_at).to eq(playlist_item1_published_at_time)
        expect(mapped_item.thumbnail_url).to eq(playlist_item1_thumb_url)

        expect(mock_logger).to have_received(:info).with("Successfully fetched uploads playlist ID: #{mock_uploads_playlist_id}")
        expect(mock_logger).to have_received(:info).with("Fetching playlist items from playlist ID: #{mock_uploads_playlist_id} with max_results: #{max_results_option}, page_token: #{page_token_option}")
        expect(mock_logger).to have_received(:info).with("Successfully fetched 1 video items from playlist: #{mock_uploads_playlist_id}")
        expect(mock_logger).to have_received(:info).with("Mapped 1 items to VideoListItem entities.")
      end

      it 'uses default max_results (25) if not provided in options' do
         # Expect list_playlist_items to be called with default max_results
        expect(mock_youtube_service).to receive(:list_playlist_items)
          .with('snippet', playlist_id: mock_uploads_playlist_id, max_results: 25, page_token: nil) # page_token is nil as not in options for this test
          .and_return(playlist_items_response)
        gateway.list_videos(options: {}) # Call with empty options
      end
    end

    context 'with malformed playlist items' do
      before do
        allow(mock_youtube_service).to receive(:list_channels)
          .with('contentDetails', mine: true)
          .and_return(channel_response)
      end

      it 'skips items with missing video_id and logs a warning' do
        response_with_malformed = Google::Apis::YoutubeV3::ListPlaylistItemsResponse.new # Corrected
        response_with_malformed.items = [playlist_item1, playlist_item_malformed_video_id]
        allow(mock_youtube_service).to receive(:list_playlist_items).and_return(response_with_malformed)

        expect(mock_logger).to receive(:warn).with("Skipping playlist item due to missing snippet, resource_id, or video_id. Item ID: #{playlist_item_malformed_video_id.id}")

        video_list_items = gateway.list_videos(options: options)
        expect(video_list_items.size).to eq(1) # Only playlist_item1 should be mapped
        expect(video_list_items.first.id).to eq(playlist_item1_video_id)
      end

      it 'handles unparseable published_at dates and logs a warning' do
        response_with_bad_date = Google::Apis::YoutubeV3::ListPlaylistItemsResponse.new # Corrected
        response_with_bad_date.items = [playlist_item_unparseable_date]
        allow(mock_youtube_service).to receive(:list_playlist_items).and_return(response_with_bad_date)

        # Adjust expected message to match Time.parse's actual error for this input
        expected_error_message = "no time information in \"Definitely not a date\""
        expect(mock_logger).to receive(:warn).with("Failed to parse published_at for video ID video_baddate: #{expected_error_message}. Raw value: 'Definitely not a date'")

        video_list_items = gateway.list_videos(options: options)
        expect(video_list_items.size).to eq(1)
        expect(video_list_items.first.id).to eq('video_baddate')
        expect(video_list_items.first.published_at).to be_nil
      end
    end
  end
end
