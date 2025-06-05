# frozen_string_literal: true

require 'spec_helper'
require 'use_cases/list_videos_use_case' # Adjust path as per your structure
# Mock or forward declare dependencies if not fully loaded by spec_helper
# For this use case, we primarily need a mock gateway.
# Entities::VideoListItem might be needed if we check the type of returned array elements.

module Gateways
  # Minimal mock for YouTubeServiceGateway for this spec
  class MockYouTubeServiceGateway
    # This will be stubbed using RSpec's `allow` and `receive`
    def list_videos(options: {})
      # To be stubbed
    end
  end
end

module Entities # Forward declare if not already loaded
  class VideoListItem; end
end


RSpec.describe UseCases::ListVideosUseCase do
  describe '.execute' do
    let(:mock_gateway) { Gateways::MockYouTubeServiceGateway.new }
    let(:video_list_item) { instance_double(Entities::VideoListItem) } # A generic video item

    it 'calls list_videos on the youtube_gateway with given options' do
      options = { max_results: 10 }
      expect(mock_gateway).to receive(:list_videos).with(options: options).and_return([video_list_item])

      result = described_class.execute(youtube_gateway: mock_gateway, options: options)
      expect(result).to eq([video_list_item])
    end

    it 'returns the result from the youtube_gateway' do
      expected_videos = [video_list_item, video_list_item]
      allow(mock_gateway).to receive(:list_videos).and_return(expected_videos)

      result = described_class.execute(youtube_gateway: mock_gateway, options: {})
      expect(result).to eq(expected_videos)
    end

    it 'returns an empty array if the gateway returns an empty array' do
      allow(mock_gateway).to receive(:list_videos).and_return([])

      result = described_class.execute(youtube_gateway: mock_gateway, options: {})
      expect(result).to be_empty
    end

    it 'raises an ArgumentError if the gateway does not respond to list_videos' do
      faulty_gateway = Object.new # A plain object that doesn't have list_videos

      expect {
        described_class.execute(youtube_gateway: faulty_gateway, options: {})
      }.to raise_error(ArgumentError, 'The provided youtube_gateway does not support list_videos')
    end

    context 'when the gateway raises an error' do
      it 'catches StandardError, prints a message, and returns an empty array' do
        allow(mock_gateway).to receive(:list_videos).and_raise(StandardError.new("Gateway exploded"))

        expect {
          result = described_class.execute(youtube_gateway: mock_gateway, options: {})
          expect(result).to be_empty
        }.to output(/Error in ListVideosUseCase: Gateway exploded/).to_stdout
      end

      it 'catches specific errors like Google::Apis::ClientError and returns an empty array' do
        # Simulate a specific error type if your gateway could raise it directly
        # For this test, StandardError is sufficient as per current use case implementation
        # but if the use case handled specific errors differently, you'd test that.
        stub_const("Google::Apis::ClientError", Class.new(StandardError)) unless defined?(Google::Apis::ClientError)

        allow(mock_gateway).to receive(:list_videos).and_raise(Google::Apis::ClientError.new("API Quota Exceeded"))

        expect {
          result = described_class.execute(youtube_gateway: mock_gateway, options: {})
          expect(result).to be_empty
        }.to output(/Error in ListVideosUseCase: API Quota Exceeded/).to_stdout
      end
    end
  end
end
