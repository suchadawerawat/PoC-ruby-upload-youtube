# frozen_string_literal: true

require 'rspec'
require 'time' # For Time.parse
require_relative '../../app/entities/upload_log_entry' # Adjust path as needed

RSpec.describe Entities::UploadLogEntry do
  let(:timestamp_str) { "2023-10-26T10:00:00Z" }
  let(:timestamp_time) { Time.parse(timestamp_str) }
  let(:valid_attributes) do
    {
      upload_timestamp: timestamp_time,
      input_video_name: "original_video.mov",
      youtube_url: "https://youtu.be/abcdef123",
      title: "Uploaded Video Title",
      status: "success"
    }
  end

  subject(:log_entry) { described_class.new(**valid_attributes) }

  it "initializes with correct attributes" do
    expect(log_entry.upload_timestamp).to eq(timestamp_time)
    expect(log_entry.input_video_name).to eq("original_video.mov")
    expect(log_entry.youtube_url).to eq("https://youtu.be/abcdef123")
    expect(log_entry.title).to eq("Uploaded Video Title")
    expect(log_entry.status).to eq("success")
  end

  it "accepts a String for upload_timestamp and parses it" do
    entry = described_class.new(**valid_attributes.merge(upload_timestamp: timestamp_str))
    expect(entry.upload_timestamp).to eq(timestamp_time)
  end

  describe "#to_h" do
    it "returns a hash representation" do
      expected_hash = {
        upload_timestamp: timestamp_time.iso8601,
        input_video_name: "original_video.mov",
        youtube_url: "https://youtu.be/abcdef123",
        title: "Uploaded Video Title",
        status: "success"
      }
      expect(log_entry.to_h).to eq(expected_hash)
    end
  end

  describe "#to_csv_row" do
    it "returns an array representation for CSV" do
      expected_array = [
        timestamp_time.iso8601,
        "original_video.mov",
        "Uploaded Video Title",
        "success",
        "https://youtu.be/abcdef123"
      ]
      expect(log_entry.to_csv_row).to eq(expected_array)
    end
  end

  context "with invalid parameters" do
    it "raises ArgumentError if upload_timestamp is nil" do
      expect { described_class.new(**valid_attributes.merge(upload_timestamp: nil)) }.to raise_error(ArgumentError, "Upload timestamp cannot be nil")
    end

    it "raises ArgumentError if input_video_name is empty" do
      expect { described_class.new(**valid_attributes.merge(input_video_name: " ")) }.to raise_error(ArgumentError, "Input video name cannot be empty")
    end

    it "raises ArgumentError if youtube_url is empty for a successful upload" do
      expect { described_class.new(**valid_attributes.merge(youtube_url: "", status: "success")) }.to raise_error(ArgumentError, "YouTube URL cannot be empty for a successful upload")
    end

    it "does not raise ArgumentError if youtube_url is empty for a failed upload" do
      expect { described_class.new(**valid_attributes.merge(youtube_url: "", status: "failure")) }.not_to raise_error
    end

    it "raises ArgumentError if title is empty" do
      expect { described_class.new(**valid_attributes.merge(title: "")) }.to raise_error(ArgumentError, "Title cannot be empty")
    end

    it "raises ArgumentError if status is invalid" do
      expect { described_class.new(**valid_attributes.merge(status: "pending")) }.to raise_error(ArgumentError, "Status must be 'success' or 'failure'")
    end
  end
end
