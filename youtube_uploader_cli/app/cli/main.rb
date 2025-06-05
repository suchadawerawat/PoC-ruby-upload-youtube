# frozen_string_literal: true

require 'thor'
require 'gateways/cli_youtube_service_gateway' # For Cli::Main to use
require 'dotenv/load' # Ensure ENV vars are loaded for the CLI

module Cli
  # Main class for the YouTube Uploader CLI using Thor.
  class Main < Thor
    # Standard Thor options for help and version.
    class_option :help, type: :boolean, aliases: '-h', desc: 'Display usage information'
    class_option :version, type: :boolean, aliases: '-v', desc: 'Display version'

    desc "upload FILE_PATH", "Uploads a video to YouTube."
    option :title, type: :string, aliases: '-t', desc: "Title of the video on YouTube."
    option :description, type: :string, aliases: '-d', desc: "Description of the video."
    option :category_id, type: :string, aliases: '-c', desc: "YouTube category ID (e.g., '22' for People & Blogs)."
    option :privacy_status, type: :string, aliases: '-p', default: 'private', desc: "Privacy status: public, private, or unlisted."
    option :tags, type: :array, aliases: '-g', desc: "Comma-separated list of tags for the video."
    def upload(file_path)
      if options[:version]
        invoke :version
        return
      end

      puts "Placeholder: Attempting to upload video from: #{file_path}"
      puts "Title: #{options[:title]}"
      puts "Description: #{options[:description]}"
      puts "Category ID: #{options[:category_id]}"
      puts "Privacy Status: #{options[:privacy_status]}"
      puts "Tags: #{options[:tags]&.join(', ')}"
      # Actual implementation will involve calling use cases.
    end

    desc "auth", "Authenticates with Google to allow YouTube uploads."
    def auth
      puts 'Attempting to authenticate with Google...'
      config = {
        client_secret_path: ENV.fetch('GOOGLE_CLIENT_SECRET_PATH', 'config/client_secret.json'),
        tokens_path: ENV.fetch('YOUTUBE_TOKENS_PATH', 'config/tokens.yaml'),
        app_name: ENV.fetch('YOUTUBE_APP_NAME', 'Ruby YouTube Uploader CLI')
      }

      gateway = Gateways::CliYouTubeServiceGateway.new

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
      # In a real app, you might load this from a VERSION file or constant
      puts "YouTube Uploader CLI version 0.1.0 (Placeholder)"
    end
    map %w[--version -v] => :version


    # Make sure help is shown if no command is given
    def self.exit_on_failure?
      true
    end
  end
end
