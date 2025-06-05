# frozen_string_literal: true

require 'rspec'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/youtube_v3'
require_relative '../../app/gateways/cli_youtube_service_gateway'
require 'tempfile' # For temporary files
require 'fileutils' # To ensure dir exists for token store

RSpec.describe Gateways::CliYouTubeServiceGateway do
  let(:gateway) { described_class.new }
  let!(:client_secret_file) { Tempfile.new(['client_secret', '.json']) } # Use let! to ensure file is created before each test
  let!(:tokens_file) { Tempfile.new(['tokens', '.yaml']) }

  let(:config) do
    {
      client_secret_path: client_secret_file.path,
      tokens_path: tokens_file.path,
      app_name: 'TestApp'
    }
  end

  # Prepare a dummy client secret content
  let(:dummy_client_secret_content) do
    '{ "installed": { "client_id": "test_client_id_from_file", "client_secret": "test_client_secret_from_file" } }'
  end

  # Mock objects for Google API interactions
  let(:mock_client_id) { instance_double(Google::Auth::ClientId, id: 'test_client_id_from_file', secret: 'test_client_secret_from_file') }
  let(:mock_token_store) { instance_double(Google::Auth::Stores::FileTokenStore) }
  let(:mock_authorizer) { instance_double(Google::Auth::UserAuthorizer) }
  let(:mock_credentials) { instance_double(Google::Auth::UserRefreshCredentials, access_token: 'valid_access_token', expired?: false) }

  before do
    # Write dummy client secret content to the temp file and rewind
    client_secret_file.write(dummy_client_secret_content)
    client_secret_file.rewind

    # Ensure the directory for the tokens_file exists, similar to FileUtils.mkdir_p in the gateway
    FileUtils.mkdir_p(File.dirname(tokens_file.path))

    # Stub the chain of Google Auth object creations
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
        # Ensure the file does not exist for this specific test
        File.delete(client_secret_file.path) if File.exist?(client_secret_file.path)
        expect { gateway.authenticate(config: config) }
          .to raise_error("Client secret file not found at: #{client_secret_file.path}. Please download it from Google Cloud Console and place it correctly.")
      end
    end

    context 'when valid stored credentials exist' do
      before do
        allow(mock_authorizer).to receive(:get_credentials).with('default_user').and_return(mock_credentials)
      end

      it 'returns an authorized YouTubeService' do
        service = gateway.authenticate(config: config)
        expect(service).to be_a(Google::Apis::YoutubeV3::YouTubeService)
        expect(service.authorization).to eq(mock_credentials)
        expect(service.client_options.application_name).to eq('TestApp')
      end
    end

    context 'when no stored credentials exist (requires OAuth flow)' do
      let(:auth_url) { 'https://accounts.google.com/o/oauth2/auth?approval_prompt=force&...' }
      let(:auth_code) { 'test_auth_code' }
      # Proc double for user interaction
      let(:user_interaction_proc) { instance_double(Proc, 'UserInteractionProvider') }


      before do
        allow(mock_authorizer).to receive(:get_credentials).with('default_user').and_return(nil) # No initial credentials
        allow(mock_authorizer).to receive(:get_authorization_url)
          .with(base_url: Gateways::CliYouTubeServiceGateway::OOB_URI)
          .and_return(auth_url)
        allow(mock_authorizer).to receive(:get_and_store_credentials_from_code)
          .with(user_id: 'default_user', code: auth_code, base_url: Gateways::CliYouTubeServiceGateway::OOB_URI)
          .and_return(mock_credentials)
      end

      it 'prompts user, exchanges code, stores credentials, and returns YouTubeService' do
        # Expect the proc to be called with the instructions
        expected_instructions = Gateways::YouTubeServiceGateway.get_authorization_instructions(auth_url: auth_url) # Use module function
        expect(user_interaction_proc).to receive(:call).with(expected_instructions).and_return(auth_code)

        service = gateway.authenticate(config: config, user_interaction_provider: user_interaction_proc)

        expect(service).to be_a(Google::Apis::YoutubeV3::YouTubeService)
        expect(service.authorization).to eq(mock_credentials)
        expect(mock_authorizer).to have_received(:get_and_store_credentials_from_code) # Verify this was called
      end

      it 'raises an error if auth code is not provided by user_interaction_provider' do
        expected_instructions = Gateways::YouTubeServiceGateway.get_authorization_instructions(auth_url: auth_url) # Use module function
        expect(user_interaction_proc).to receive(:call).with(expected_instructions).and_return("") # Empty code

        expect { gateway.authenticate(config: config, user_interaction_provider: user_interaction_proc) }
          .to raise_error("Authentication cancelled or code not provided.")
      end

      it 'uses STDIN if no user_interaction_provider is given (manual test simulation)' do
        # This case is hard to test fully without actual STDIN interaction.
        # We'll ensure get_authorization_instructions is called (via the module) and then simulate empty input.
        expected_instructions = Gateways::YouTubeServiceGateway.get_authorization_instructions(auth_url: auth_url) # This method is from the module
        # The gateway's authenticate method internally calls `puts` with these instructions.
        # We need to allow the gateway instance to call `puts`.
        expect_any_instance_of(described_class).to receive(:puts).with(expected_instructions).and_call_original
        allow(STDIN).to receive_message_chain(:gets, :chomp, :strip).and_return("") # Simulate user pressing enter

        expect { gateway.authenticate(config: config, user_interaction_provider: nil) }
          .to raise_error("Authentication cancelled or code not provided.")
      end
    end

    context 'when get_credentials returns nil and then get_and_store_credentials_from_code also returns nil' do
      before do
        allow(mock_authorizer).to receive(:get_credentials).with('default_user').and_return(nil)
        allow(mock_authorizer).to receive(:get_authorization_url).and_return('some_auth_url')
        allow(mock_authorizer).to receive(:get_and_store_credentials_from_code).and_return(nil) # Simulate failure to get credentials
      end

      it 'raises an error "Failed to obtain credentials."' do
         user_interaction_stub = proc { "any_code" } # Simulate user providing some code
         expect { gateway.authenticate(config: config, user_interaction_provider: user_interaction_stub) }
           .to raise_error("Failed to obtain credentials.")
      end
    end
  end

  # Tests for #upload_video will be added in a subsequent step when it's implemented.
end
