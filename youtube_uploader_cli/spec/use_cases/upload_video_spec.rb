# frozen_string_literal: true

require 'rspec'
require_relative '../../app/use_cases/upload_video'
require_relative '../../app/entities/video_details' # Needed for creating an instance
require_relative '../../app/entities/upload_log_entry' # Needed for log entry double

# Define dummy classes that adhere to the gateway interface contracts for testing
module Gateways
  module YouTubeServiceGateway
    # This is a Test Double for the real YouTubeServiceGateway
    class MockYouTubeGateway
      def authenticate(config:); end
      def upload_video(video_data:); end
    end
  end

  module LogPersistenceGateway
    # This is a Test Double for the real LogPersistenceGateway
    class MockLogGateway
      def save(log_entry:); end
    end
  end
end


# A dummy class that would include/implement the use case for testing its contract
class DummyUploadVideoInteractor
  include UseCases::UploadVideoUseCase

  # This is a sample implementation just for the sake of showing contract testing.
  # A real implementation would have more logic.
  def execute(video_details:, youtube_gateway:, log_gateway:)
    # Simulate interaction
    youtube_gateway.upload_video(video_data: video_details) # Simplified for contract test

    # Simulate creating a log entry and logging it
    # In a real scenario, the YouTube URL would come from the youtube_gateway response
    log_data = Entities::UploadLogEntry.new(
      upload_timestamp: Time.now,
      input_video_name: video_details.file_path, # or some other identifier
      youtube_url: "https://example.com/fake_url",
      title: video_details.title,
      status: "success" # Or determine based on youtube_gateway response
    )
    log_gateway.save(log_entry: log_data)

    return "https://example.com/fake_url" # Example return
  rescue StandardError => e
    # Simulate error logging or handling
    log_data = Entities::UploadLogEntry.new(
      upload_timestamp: Time.now,
      input_video_name: video_details.file_path,
      youtube_url: "",
      title: video_details.title,
      status: "failure"
    )
    log_gateway.save(log_entry: log_data)
    raise e # Re-raise or return error indicator
  end
end

RSpec.describe UseCases::UploadVideoUseCase do
  # We test the contract using a dummy interactor that includes the use case module.
  let(:interactor) { DummyUploadVideoInteractor.new }
  let(:video_details) do
    Entities::VideoDetails.new(
      file_path: "/tmp/video.mp4",
      title: "Test Video",
      description: "A test video.",
      tags: ["test"],
      category_id: "22",
      privacy_status: "private"
    )
  end
  let(:youtube_gateway_double) { instance_double(Gateways::YouTubeServiceGateway::MockYouTubeGateway) }
  let(:log_gateway_double) { instance_double(Gateways::LogPersistenceGateway::MockLogGateway) }

  before do
    # Allow methods on the doubles that are expected to be called
    allow(youtube_gateway_double).to receive(:upload_video).and_return({ success: true, url: "https://example.com/fake_url" })
    allow(log_gateway_double).to receive(:save)
  end

  it "is expected to be included in a class that implements #execute" do
    expect(interactor).to respond_to(:execute)
  end

  it "calls #upload_video on the YouTube gateway" do
    expect(youtube_gateway_double).to receive(:upload_video).with(video_data: video_details)
    interactor.execute(
      video_details: video_details,
      youtube_gateway: youtube_gateway_double,
      log_gateway: log_gateway_double
    )
  end

  it "calls #save on the Log gateway after a successful upload" do
    # ArgumentCaptor for log_entry might be too complex for a pure contract test,
    # so we check if it's called with any instance of UploadLogEntry.
    expect(log_gateway_double).to receive(:save).with(log_entry: an_instance_of(Entities::UploadLogEntry))
    interactor.execute(
      video_details: video_details,
      youtube_gateway: youtube_gateway_double,
      log_gateway: log_gateway_double
    )
  end

  it "calls #save on the Log gateway with failure status if upload fails" do
    allow(youtube_gateway_double).to receive(:upload_video).and_raise(StandardError.new("Upload failed"))
    expect(log_gateway_double).to receive(:save).with(log_entry: an_instance_of(Entities::UploadLogEntry)) do |args|
        expect(args[:log_entry].status).to eq("failure")
    end

    expect {
        interactor.execute(
            video_details: video_details,
            youtube_gateway: youtube_gateway_double,
            log_gateway: log_gateway_double
        )
    }.to raise_error(StandardError, "Upload failed")
  end

  # It's the responsibility of the concrete use case to define what it returns.
  # The interface itself doesn't dictate the return type strictly, other than it being "the result".
  # So, we test that the dummy implementation returns something.
  it "returns the result from the (dummy) upload process" do
    result = interactor.execute(
      video_details: video_details,
      youtube_gateway: youtube_gateway_double,
      log_gateway: log_gateway_double
    )
    expect(result).not_to be_nil
    expect(result).to eq("https://example.com/fake_url")
  end
end
