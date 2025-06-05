# frozen_string_literal: true

require 'rspec'
require_relative '../../app/gateways/log_persistence_gateway'
require_relative '../../app/entities/upload_log_entry' # Required for method signature

# A dummy class that would include/implement the gateway module for testing its contract
class DummyLogPersistence
  include Gateways::LogPersistenceGateway

  def save(log_entry:); :saved end # Minimal implementation for contract
end

RSpec.describe Gateways::LogPersistenceGateway do
  let(:gateway_implementer) { DummyLogPersistence.new }
  let(:log_entry_double) { instance_double(Entities::UploadLogEntry) }

  it "expects implementers to define a #save method" do
    expect(gateway_implementer).to respond_to(:save).with_keywords(:log_entry)
    # Test that calling it on an object that *has* implemented it doesn't raise NotImplementedError
    expect { gateway_implementer.save(log_entry: log_entry_double) }.not_to raise_error(NotImplementedError)
  end

  context "when a method is not implemented by a class directly including the module" do
    it "raises NotImplementedError for #save if not implemented" do
      # This tests that if you try to call the module function directly without it being implemented
      # (or if a class includes it but doesn't define #save), it raises.
      expect { Gateways::LogPersistenceGateway.save(log_entry: log_entry_double) }.to raise_error(NotImplementedError)
    end
  end
end
