# frozen_string_literal: true

module Gateways
  # Module defining the contract for a YouTube Service Gateway.
  # Concrete implementations will handle the actual communication with the YouTube API.
  # This interface is designed to be generic and not tied to a specific API client library.
  module YouTubeServiceGateway
    # Authenticates with the YouTube service.
    #
    # @param config [Hash] Configuration required for authentication (e.g., client secrets path, tokens path).
    # @return [Object] An authenticated client object or session, or raises an error on failure.
    #   The specific nature of the return depends on the concrete implementation.
    def authenticate(config:)
      raise NotImplementedError, "\#{self.class} has not implemented method '#{__method__}'"
    end

    # Uploads a video to YouTube.
    #
    # @param video_data [Entities::VideoDetails] An entity containing all necessary video information.
    # @return [Hash] A hash containing details of the uploaded video (e.g., { success: true, video_id: '...', youtube_url: '...' })
    #   or an error indication (e.g., { success: false, error: '...' }).
    def upload_video(video_data:)
      raise NotImplementedError, "\#{self.class} has not implemented method '#{__method__}'"
    end

    # Optional: A method to get user-friendly authorization instructions for CLI
    def get_authorization_instructions(auth_url:)
        "Please open this URL in your browser to authorize the application:
" +
        auth_url + "
" +
        "After authorization, copy the code from your browser and paste it here: "
    end

    # Optional: A method to handle the callback/code exchange for CLI
    # This might be part of authenticate or separate depending on flow
    def exchange_code_for_tokens(code:, config:)
        raise NotImplementedError, "\#{self.class} has not implemented method '#{__method__}'"
    end

    # Make methods available as module functions if this module is used directly
    # or if a class wants to call them in a functional way.
    # However, typically these would be implemented by a class including this module.
    module_function :authenticate, :upload_video, :get_authorization_instructions, :exchange_code_for_tokens
  end
end
