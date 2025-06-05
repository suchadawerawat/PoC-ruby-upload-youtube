# frozen_string_literal: true

require_relative '../entities/video_details'
# Forward declare gateway modules to define the interface contract
module Gateways
  module YouTubeServiceGateway
  end
  module LogPersistenceGateway
  end
end

module UseCases
  # Module defining the contract for the UploadVideo use case.
  # Concrete implementations of this use case will handle the orchestration
  # of uploading a video and logging the result.
  module UploadVideoUseCase
    # Executes the video upload process.
    #
    # @param video_details [Entities::VideoDetails] The details of the video to upload.
    # @param youtube_gateway [Gateways::YouTubeServiceGateway] The gateway for interacting with YouTube.
    # @param log_gateway [Gateways::LogPersistenceGateway] The gateway for persisting log information.
    # @return [Object] The result of the upload attempt (e.g., YouTube URL or error information).
    #   The specific structure of the return will be defined by concrete implementations.
    def execute(video_details:, youtube_gateway:, log_gateway:)
      raise NotImplementedError, "\#{self.class} has not implemented method '#{__method__}'"
    end
    module_function :execute # Allows calling as UseCases::UploadVideoUseCase.execute if mixed into a class
  end
end
