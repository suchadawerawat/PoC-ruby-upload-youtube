# frozen_string_literal: true

require 'rspec'
require_relative '../../app/gateways/youtube_service_gateway'
require_relative '../../app/entities/video_details' # Required for method signature

# A dummy class that would include/implement the gateway module for testing its contract
class DummyYouTubeService
  include Gateways::YouTubeServiceGateway

  # Provide minimal implementations for contract testing
  def authenticate(config:); :authenticated_client end
  def upload_video(video_data:); { success: true, video_id: 'dummy_id', youtube_url: 'http://dummy.url' } end
  def exchange_code_for_tokens(code:, config:); :tokens_exchanged end
  # get_authorization_instructions has a default implementation in the module if not overridden
end

RSpec.describe Gateways::YouTubeServiceGateway do
  let(:gateway_implementer) { DummyYouTubeService.new }
  let(:video_details_double) { instance_double(Entities::VideoDetails) }
  let(:config_double) { { client_secret_path: 'path', tokens_path: 'tokens' } }


  it "expects implementers to define an #authenticate method" do
    expect(gateway_implementer).to respond_to(:authenticate).with_keywords(:config)
    expect { gateway_implementer.authenticate(config: config_double) }.not_to raise_error
  end

  it "expects implementers to define an #upload_video method" do
    expect(gateway_implementer).to respond_to(:upload_video).with_keywords(:video_data)
    expect { gateway_implementer.upload_video(video_data: video_details_double) }.not_to raise_error
  end

  it "expects implementers to define an #exchange_code_for_tokens method (optional, but part of typical OAuth CLI flow)" do
    expect(gateway_implementer).to respond_to(:exchange_code_for_tokens).with_keywords(:code, :config)
    expect { gateway_implementer.exchange_code_for_tokens(code: "some_code", config: config_double) }.not_to raise_error
  end

  it "provides a default #get_authorization_instructions method as a module function" do
    # Test the module function directly
    expect(Gateways::YouTubeServiceGateway).to respond_to(:get_authorization_instructions).with_keywords(:auth_url)
    auth_url = "http://example.com/auth"
    instructions = Gateways::YouTubeServiceGateway.get_authorization_instructions(auth_url: auth_url)
    expect(instructions).to include(auth_url)
    expect(instructions).to include("Please open this URL")
  end

  context "when a method is not implemented by a class directly including the module" do
    # This tests the module's default NotImplementedError behavior if used without a concrete class
    # or if a concrete class forgets to implement a method.
    it "raises NotImplementedError for #authenticate if not implemented" do
      expect { Gateways::YouTubeServiceGateway.authenticate(config: {}) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #upload_video if not implemented" do
      expect { Gateways::YouTubeServiceGateway.upload_video(video_data: video_details_double) }.to raise_error(NotImplementedError)
    end
  end
end
