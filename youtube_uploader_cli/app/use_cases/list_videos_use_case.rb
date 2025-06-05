# frozen_string_literal: true

# Forward declare gateway module and entity to define the interface contract
module Gateways
  module YouTubeServiceGateway
    # list_videos(options: {})
  end
end

module Entities
  class VideoListItem
  end
end

module UseCases
  # Module defining the contract for the ListVideosUseCase.
  # Concrete implementations (or the module itself if used directly)
  # will handle the orchestration of listing videos.
  module ListVideosUseCase
    # Executes the video listing process.
    #
    # @param youtube_gateway [Gateways::YouTubeServiceGateway] The gateway for interacting with YouTube.
    # @param options [Hash] Options to pass to the gateway's list_videos method (e.g., :max_results).
    # @return [Array<Entities::VideoListItem>] An array of video list items.
    #   Returns an empty array if no videos are found or in case of errors handled by the gateway.
    def execute(youtube_gateway:, options: {})
      unless youtube_gateway.respond_to?(:list_videos)
        raise ArgumentError, 'The provided youtube_gateway does not support list_videos'
      end

      youtube_gateway.list_videos(options: options)
    rescue StandardError => e
      # Log the error or handle it as per application requirements
      # For now, re-raise to make it visible or let the CLI handle displaying it
      # In a real app, you might have a specific error handling strategy here
      puts "Error in ListVideosUseCase: #{e.message}"
      # Consider returning a structured error response or an empty array
      [] # Return empty array on error to prevent crashes in CLI
    end
    module_function :execute # Allows calling as UseCases::ListVideosUseCase.execute
  end
end
