# frozen_string_literal: true

require 'rspec'
require 'open3' # For capturing CLI output
require 'tempfile' # For auth command's dummy files
require 'fileutils' # For auth command's dummy files

# For CLI executable tests
require 'gateways/cli_youtube_service_gateway' # For mocking/stubbing (though less used in Open3 tests)

# For CLI class unit tests
require 'cli/main'
require 'use_cases/list_videos_use_case'
require 'entities/video_list_item'


# --- Tests for CLI Executable (Integration Style) ---
RSpec.describe "Cli::Main Executable" do # Renamed to clarify scope
  let(:executable_path) { File.expand_path('../../../bin/youtube_upload', __FILE__) }

  # ... (Existing Open3 tests for help, version, placeholder upload, auth command) ...
  # (Keeping them as they are for brevity in this example, assuming they were here)
  describe "invocation" do
    it "shows help when invoked with --help" do
      stdout, stderr, status = Open3.capture3(executable_path, "--help")
      expect(stderr).to be_empty
      expect(status.success?).to be true
      expect(stdout).to include("Commands:")
      expect(stdout).to include("youtube_upload help")
      # expect(stdout).to include("youtube_upload list") # This would be added if testing help output for list
      expect(stdout).to include("youtube_upload upload FILE_PATH")
      expect(stdout).to include("youtube_upload version")
    end

    it "shows help when invoked with no arguments" do
      stdout, stderr, status = Open3.capture3(executable_path)
      expect(stderr).to be_empty
      expect(stdout).to include("Commands:")
      expect(stdout).to include("youtube_upload upload")
    end

    it "shows version when invoked with --version" do
      stdout, stderr, status = Open3.capture3(executable_path, "--version")
      expect(stderr).to be_empty
      expect(status.success?).to be true
      expect(stdout).to include("YouTube Uploader CLI version")
    end

    it "shows version when invoked with -v" do
      stdout, stderr, status = Open3.capture3(executable_path, "-v")
      expect(stderr).to be_empty
      expect(status.success?).to be true
      expect(stdout).to include("YouTube Uploader CLI version")
    end

    it "shows version when 'version' command is used" do
      stdout, stderr, status = Open3.capture3(executable_path, "version")
      expect(stderr).to be_empty
      expect(status.success?).to be true
      expect(stdout).to include("YouTube Uploader CLI version")
    end
  end

  describe "upload command (placeholder)" do
    it "runs the placeholder upload command and shows options" do
      stdout, stderr, status = Open3.capture3(executable_path, "upload", "my_video.mp4", "-t", "Test Title", "-c", "22")
      expect(stderr).to be_empty
      expect(status.success?).to be true
      expect(stdout).to include("Placeholder: Attempting to upload video from: my_video.mp4")
      expect(stdout).to include("Title: Test Title")
      expect(stdout).to include("Category ID: 22")
      expect(stdout).to include("Privacy Status: private") # Default
    end
  end

  describe "auth command (executable tests)" do
    let!(:dummy_secret_tempfile) { Tempfile.new(['dummy_client_secret', '.json']) }
    let!(:dummy_tokens_tempfile) { Tempfile.new(['dummy_tokens', '.yaml']) }

    let(:base_env_vars) do
      {
        'YOUTUBE_APP_NAME' => 'DummyAppForCliTest',
      }
    end

    after do
      dummy_secret_tempfile.close
      dummy_secret_tempfile.unlink
      dummy_tokens_tempfile.close
      dummy_tokens_tempfile.unlink
    end

    context "when client secret file is missing" do
      it "reports an error" do
        env_for_test = base_env_vars.merge('GOOGLE_CLIENT_SECRET_PATH' => 'non_existent_file.json')
        stdout, _stderr, status = Open3.capture3(env_for_test, executable_path, "auth")
        expect(status.success?).to be true
        expect(stdout).to include("Client secret file not found at: non_existent_file.json")
      end
    end

    context "when client secret file exists (using a dummy one)" do
      before do
        dummy_secret_tempfile.write('{ "installed": { "client_id": "test", "client_secret": "test_secret" } }')
        dummy_secret_tempfile.rewind
        FileUtils.touch(dummy_tokens_tempfile.path)
      end

      let(:current_env_vars) do
        base_env_vars.merge(
          'GOOGLE_CLIENT_SECRET_PATH' => dummy_secret_tempfile.path,
          'YOUTUBE_TOKENS_PATH' => dummy_tokens_tempfile.path
        )
      end

      context "and no existing tokens are found, requiring new OAuth flow" do
        it "attempts auth, prints URL, then fails at Google due to invalid client" do
          stdout, stderr, status = Open3.capture3(current_env_vars, executable_path, "auth", stdin_data: "test_auth_code\n")
          expect(stderr).to be_empty
          expect(status.success?).to be true
          expect(stdout).to include("Attempting to authenticate with Google...")
          expect(stdout).to include("Please open this URL in your browser")
          expect(stdout).to include("https://accounts.google.com/o/oauth2/auth")
          expect(stdout).to include("An error occurred during authentication: Authorization failed.")
          expect(stdout).to include("\"error\": \"invalid_client\"")
        end

        it "reports 'Authentication cancelled' if empty auth code is provided via STDIN" do
          stdout, stderr, status = Open3.capture3(current_env_vars, executable_path, "auth", stdin_data: "\n")
          expect(stderr).to be_empty
          expect(status.success?).to be true
          expect(stdout).to include("Attempting to authenticate with Google...")
          expect(stdout).to include("Please open this URL in your browser")
          expect(stdout).to include("Authentication cancelled or code not provided.")
        end
      end
    end
  end
end


# --- Tests for Cli::Main Class (Unit Style) ---
RSpec.describe Cli::Main do
  # This uses $stdout redirection and mocks, common for unit testing Thor CLI classes.
  # It does not run the executable in a subprocess.

  describe '#list' do
    let(:mock_gateway) { instance_double(Gateways::CliYouTubeServiceGateway) }
    # Mock for the actual service client returned by gateway.authenticate
    let(:mock_authenticated_service) { instance_double(Google::Apis::YoutubeV3::YouTubeService) }
    # Mock for the credentials object within the authenticated service
    let(:mock_auth_credentials) { instance_double(Google::Auth::UserRefreshCredentials, access_token: 'fake-token') }

    before do
      # Stub the gateway instantiation
      allow(Gateways::CliYouTubeServiceGateway).to receive(:new).and_return(mock_gateway)

      # Stub the authenticate call on the gateway instance
      # It should return the mock_authenticated_service
      allow(mock_gateway).to receive(:authenticate).and_return(mock_authenticated_service)

      # Ensure the mock_authenticated_service has a valid authorization object with an access token
      allow(mock_authenticated_service).to receive(:authorization).and_return(mock_auth_credentials)

      # Mock environment variables used by the command for config
      # These ENV.fetch calls happen inside the 'list' method when it prepares its 'config' hash.
      allow(ENV).to receive(:fetch).with('GOOGLE_CLIENT_SECRET_PATH', 'config/client_secret.json').and_return('dummy_secret_path')
      allow(ENV).to receive(:fetch).with('YOUTUBE_TOKENS_PATH', 'config/tokens.yaml').and_return('dummy_tokens_path')
      allow(ENV).to receive(:fetch).with('YOUTUBE_APP_NAME', 'Ruby YouTube Uploader CLI').and_return('DummyApp')
    end

    # Helper to capture stdout for the duration of a block
    def capture_stdout
      original_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end

    context 'when authentication is successful' do
      let(:video1) do
        Entities::VideoListItem.new(
          id: 'id1', title: 'Video One', youtube_url: 'http://youtube.com/watch?v=id1',
          published_at: Time.parse('2023-01-01T10:00:00Z'), thumbnail_url: 'http://thumb1.jpg'
        )
      end
      let(:video2) do
        Entities::VideoListItem.new(
          id: 'id2', title: 'Video Two', youtube_url: 'http://youtube.com/watch?v=id2',
          published_at: Time.parse('2023-02-01T10:00:00Z'), thumbnail_url: 'http://thumb2.jpg'
        )
      end

      it 'calls authenticate on the gateway and then ListVideosUseCase' do
        # Check that gateway.authenticate is called with a config hash.
        # The .ordered is important if you want to ensure authenticate is called before execute.
        expect(mock_gateway).to receive(:authenticate).with(config: instance_of(Hash)).ordered.and_return(mock_authenticated_service)

        # Check that UseCases::ListVideosUseCase.execute is called with the gateway and default options.
        # max_results will be nil if not provided by user, which is passed as options: {max_results: nil}
        expect(UseCases::ListVideosUseCase).to receive(:execute)
          .with(youtube_gateway: mock_gateway, options: {max_results: nil})
          .ordered
          .and_return([]) # Return empty to simplify this specific test

        capture_stdout do
          cli = Cli::Main.new
          cli.list # Direct method call
        end
      end

      it 'displays videos when the use case returns them' do
        allow(UseCases::ListVideosUseCase).to receive(:execute).and_return([video1, video2])

        result_output = capture_stdout do
          cli = Cli::Main.new
          cli.list
        end

        expect(result_output).to include("Authenticating...")
        expect(result_output).to include("Authentication successful.")
        expect(result_output).to include("Fetching video list...")
        expect(result_output).to include("Your Videos:")
        expect(result_output).to include("1. Video One - http://youtube.com/watch?v=id1 (Published: 2023-01-01)")
        expect(result_output).to include("2. Video Two - http://youtube.com/watch?v=id2 (Published: 2023-02-01)")
      end

      it 'passes max_results option to the use case when invoked via Thor' do
        expect(UseCases::ListVideosUseCase).to receive(:execute)
          .with(youtube_gateway: mock_gateway, options: {max_results: 5}) # Note: Thor converts to numeric
          .and_return([])

        capture_stdout do
          # When testing Thor commands with options, it's best to use `invoke`
          # or initialize with options: `Cli::Main.new([], {max_results: 5}).list`
          # Thor parses options and makes them available via `options` hash.
          # The `invoke` method handles this more like the actual CLI execution.
          Cli::Main.start(['list', '--max-results', '5'])
        end
      end

      it 'displays a message when no videos are found' do
        allow(UseCases::ListVideosUseCase).to receive(:execute).and_return([])

        result_output = capture_stdout do
          cli = Cli::Main.new
          cli.list
        end

        expect(result_output).to include("No videos found or an error occurred while fetching.")
      end
    end

    context 'when authentication fails' do
      it 'prints an error message and does not call the use case if authenticate returns nil service' do
        allow(mock_gateway).to receive(:authenticate).and_return(nil)

        expect(UseCases::ListVideosUseCase).not_to receive(:execute)

        result_output = capture_stdout do
          cli = Cli::Main.new
          cli.list
        end

        expect(result_output).to include("Authentication failed or was cancelled. Cannot list videos.")
      end

       it 'prints an error if authenticated service has no valid token' do
        # Simulate the case where authenticate returns a service, but that service's authorization is bad
        allow(mock_authenticated_service).to receive(:authorization).and_return(double('auth', access_token: nil))
        # mock_gateway.authenticate will still return mock_authenticated_service as per general before block
        # but this service now has bad credentials for the check within list method.

        expect(UseCases::ListVideosUseCase).not_to receive(:execute)

        result_output = capture_stdout do
          cli = Cli::Main.new
          cli.list
        end

        expect(result_output).to include("Authentication failed or was cancelled. Cannot list videos.")
      end
    end

    context 'when ListVideosUseCase raises an error' do
      it 'prints a generic error message' do
        # Ensure authentication part passes
        allow(mock_gateway).to receive(:authenticate).and_return(mock_authenticated_service)
        allow(mock_authenticated_service).to receive(:authorization).and_return(mock_auth_credentials)

        allow(UseCases::ListVideosUseCase).to receive(:execute).and_raise(StandardError.new("UseCase Explosion"))

        result_output = capture_stdout do
          cli = Cli::Main.new
          cli.list
        end

        expect(result_output).to include("An error occurred: UseCase Explosion")
      end
    end
  end
end
