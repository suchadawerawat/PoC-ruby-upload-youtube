# frozen_string_literal: true

require 'rspec'
require_relative '../../app/use_cases/log_upload_details'
require_relative '../../app/entities/upload_log_entry' # Needed for creating an instance

# Define a dummy class for the LogPersistenceGateway if not already defined for this test file
module Gateways
  module LogPersistenceGateway
    class MockLogGatewayForLogDetailsSpec
      def save(log_entry:); end # Adheres to the contract
    end
  end
end

# A dummy class that would include/implement the use case for testing its contract
class DummyLogDetailsInteractor
  include UseCases::LogUploadDetailsUseCase

  def execute(log_entry:, log_gateway:)
    # Simulate interaction
    log_gateway.save(log_entry: log_entry)
    return :success # Example return
  end
end

RSpec.describe UseCases::LogUploadDetailsUseCase do
  let(:interactor) { DummyLogDetailsInteractor.new }
  let(:log_entry) do
    Entities::UploadLogEntry.new(
      upload_timestamp: Time.now,
      input_video_name: "video.mp4",
      youtube_url: "https://youtu.be/123",
      title: "Test Log",
      status: "success"
    )
  end
  let(:log_gateway_double) { instance_double(Gateways::LogPersistenceGateway::MockLogGatewayForLogDetailsSpec) }

  before do
    allow(log_gateway_double).to receive(:save)
  end

  it "is expected to be included in a class that implements #execute" do
    expect(interactor).to respond_to(:execute)
  end

  it "calls #save on the Log gateway with the provided log entry" do
    expect(log_gateway_double).to receive(:save).with(log_entry: log_entry)
    interactor.execute(log_entry: log_entry, log_gateway: log_gateway_double)
  end

  it "returns the result from the (dummy) logging process" do
    result = interactor.execute(log_entry: log_entry, log_gateway: log_gateway_double)
    expect(result).to eq(:success)
  end
end
