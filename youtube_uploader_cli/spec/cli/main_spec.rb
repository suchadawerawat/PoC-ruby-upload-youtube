# frozen_string_literal: true

require 'rspec'
require 'open3' # For capturing CLI output
require 'gateways/cli_youtube_service_gateway' # For mocking/stubbing

RSpec.describe "Cli::Main" do
  let(:executable_path) { File.expand_path('../../../bin/youtube_upload', __FILE__) }

  describe "invocation" do
    it "shows help when invoked with --help" do
      stdout, stderr, status = Open3.capture3(executable_path, "--help")
      expect(stderr).to be_empty
      expect(status.success?).to be true
      expect(stdout).to include("Commands:")
      expect(stdout).to include("youtube_upload help")
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

    it "shows version when 'version' command is used (now 'print_version' mapped to 'version')" do
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

  describe "auth command" do
    let!(:dummy_secret_tempfile) { Tempfile.new(['dummy_client_secret', '.json']) }
    let!(:dummy_tokens_tempfile) { Tempfile.new(['dummy_tokens', '.yaml']) }

    let(:base_env_vars) do
      {
        'YOUTUBE_APP_NAME' => 'DummyAppForCliTest',
        # Paths will be set per test or context
      }
    end

    # No longer mocking Google API calls here directly; they will run in the subprocess.
    # We will observe the CLI's output based on how the real gateway (with dummy credentials) behaves.

    after do
      dummy_secret_tempfile.close
      dummy_secret_tempfile.unlink
      dummy_tokens_tempfile.close
      dummy_tokens_tempfile.unlink
    end

    context "when client secret file is missing" do
      it "reports an error" do
        # GOOGLE_CLIENT_SECRET_PATH is not in env_vars, so gateway uses default or fails if ENV var is mandatory
        # The gateway itself raises an error if path from config is bad.
        # The CLI's ENV.fetch will provide 'config/client_secret.json' as default.
        env_for_test = base_env_vars.merge('GOOGLE_CLIENT_SECRET_PATH' => 'non_existent_file.json')
        stdout, _stderr, status = Open3.capture3(env_for_test, executable_path, "auth")
        expect(status.success?).to be true # CLI handles the error
        expect(stdout).to include("Client secret file not found at: non_existent_file.json")
      end
    end

    context "when client secret file exists (using a dummy one)" do
      before do
        dummy_secret_tempfile.write('{ "installed": { "client_id": "test", "client_secret": "test_secret" } }')
        dummy_secret_tempfile.rewind
        # dummy_tokens_tempfile is intentionally left empty or non-existent for these tests initially
        # to force the interactive OAuth flow or failure.
        # If dummy_tokens_tempfile exists but is empty, FileTokenStore treats it as no tokens.
        # Ensure it exists for writing by the gateway if auth were to succeed.
        FileUtils.touch(dummy_tokens_tempfile.path)
      end

      let(:current_env_vars) do
        base_env_vars.merge(
          'GOOGLE_CLIENT_SECRET_PATH' => dummy_secret_tempfile.path,
          'YOUTUBE_TOKENS_PATH' => dummy_tokens_tempfile.path
        )
      end

      # Testing the "already authenticated" path with Open3.capture3 is very hard
      # because it would require pre-filling dummy_tokens_tempfile with a valid token
      # that the *actual* Google::Auth::Stores::FileTokenStore could parse and that
      # the *actual* Google::Auth::UserAuthorizer would deem valid for the dummy client_id.
      # This is too complex for this level of testing.
      # This specific scenario is better covered by the gateway's own unit tests
      # where FileTokenStore and UserAuthorizer interactions *can* be effectively mocked.
      # So, we'll remove that specific context ("and existing valid tokens are found") from CLI spec.

      context "and no existing tokens are found, requiring new OAuth flow" do
        it "attempts auth, prints URL, gets code from STDIN, then fails at Google due to invalid client" do
          stdout, stderr, status = Open3.capture3(current_env_vars, executable_path, "auth", stdin_data: "test_auth_code\n")
          expect(stderr).to be_empty # Error from Google API is on stdout via our CLI's error handling
          expect(status.success?).to be true # CLI command itself completes
          expect(stdout).to include("Attempting to authenticate with Google...")
          expect(stdout).to include("Please open this URL in your browser") # Indicates interactive flow started
          # Check for the specific auth URL structure if necessary, but its exact content is from googleauth
          expect(stdout).to include("https://accounts.google.com/o/oauth2/auth")
          expect(stdout).to include("An error occurred during authentication: Authorization failed.")
          # This is the actual error from Google's servers when using "client_id": "test"
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

      # The context "when authentication process fails after prompt" because get_and_store_credentials returns nil
      # is also hard to simulate without mocking the internals of the googleauth library in the subprocess.
      # The "invalid_client" error above is a more realistic test of the CLI's behavior with dummy credentials.
      # If get_and_store_credentials_from_code *itself* were to return nil (e.g. due to a library bug or weird response),
      # the CliYouTubeServiceGateway would raise "Failed to obtain credentials."
      # To test *that specific message* from the CLI, we'd need to somehow make the real library call return nil
      # for that method, which is difficult here. The gateway unit test already covers this.
    end
  end
end
