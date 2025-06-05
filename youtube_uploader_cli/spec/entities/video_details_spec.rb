# frozen_string_literal: true

require 'rspec'
require_relative '../../app/entities/video_details' # Adjust path as needed

RSpec.describe Entities::VideoDetails do
  subject(:video_details) do
    described_class.new(
      file_path: "/path/to/video.mp4",
      title: "My Awesome Video",
      description: "A description of my video.",
      tags: ["ruby", "youtube", "cli"],
      category_id: "22", # People & Blogs
      privacy_status: "private"
    )
  end

  it "initializes with correct attributes" do
    expect(video_details.file_path).to eq("/path/to/video.mp4")
    expect(video_details.title).to eq("My Awesome Video")
    expect(video_details.description).to eq("A description of my video.")
    expect(video_details.tags).to eq(["ruby", "youtube", "cli"])
    expect(video_details.category_id).to eq("22")
    expect(video_details.privacy_status).to eq("private")
  end

  context "with valid parameters" do
    it "does not raise an error" do
      expect { video_details }.not_to raise_error
    end
  end

  context "with invalid parameters" do
    it "raises ArgumentError if file_path is nil" do
      expect do
        described_class.new(file_path: nil, title: "T", description: "D", tags: [], category_id: "C", privacy_status: "private")
      end.to raise_error(ArgumentError, "File path cannot be empty")
    end

    it "raises ArgumentError if file_path is empty" do
      expect do
        described_class.new(file_path: " ", title: "T", description: "D", tags: [], category_id: "C", privacy_status: "private")
      end.to raise_error(ArgumentError, "File path cannot be empty")
    end

    it "raises ArgumentError if title is nil" do
      expect do
        described_class.new(file_path: "F", title: nil, description: "D", tags: [], category_id: "C", privacy_status: "private")
      end.to raise_error(ArgumentError, "Title cannot be empty")
    end

    it "allows empty description" do
      expect do
        described_class.new(file_path: "F", title: "T", description: "", tags: [], category_id: "C", privacy_status: "private")
      end.not_to raise_error
    end

    it "raises ArgumentError if category_id is empty" do
      expect do
        described_class.new(file_path: "F", title: "T", description: "D", tags: [], category_id: "", privacy_status: "private")
      end.to raise_error(ArgumentError, "Category ID cannot be empty")
    end

    it "raises ArgumentError if privacy_status is invalid" do
      expect do
        described_class.new(file_path: "F", title: "T", description: "D", tags: [], category_id: "C", privacy_status: "world_readable")
      end.to raise_error(ArgumentError, "Privacy status must be one of: public, private, unlisted")
    end

    it "raises ArgumentError if tags is not an array" do
      expect do
        described_class.new(file_path: "F", title: "T", description: "D", tags: "not-an-array", category_id: "C", privacy_status: "private")
      end.to raise_error(ArgumentError, "Tags must be an array")
    end
  end
end
