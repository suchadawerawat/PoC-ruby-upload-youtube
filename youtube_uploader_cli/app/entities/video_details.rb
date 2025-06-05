# frozen_string_literal: true

module Entities
  # Represents the metadata for a video to be uploaded.
  # This is a simple data structure (PORO) used to pass video information
  # between layers of the application.
  class VideoDetails
    attr_reader :file_path, :title, :description, :tags, :category_id, :privacy_status

    VALID_PRIVACY_STATUSES = %w[public private unlisted].freeze
    DEFAULT_PRIVACY_STATUS = 'private'.freeze
    DEFAULT_TAGS = [].freeze

    # @param file_path [String] Absolute path to the video file.
    # @param title [String] Title of the video on YouTube.
    # @param description [String] Description of the video on YouTube.
    # @param category_id [String] YouTube category ID (e.g., "22" for People & Blogs).
    # @param privacy_status [String] Privacy status ('public', 'private', 'unlisted'). Defaults to 'private'.
    # @param tags [Array<String>] Tags for the video. Defaults to an empty array.
    def initialize(file_path:, title:, description:, category_id:, privacy_status: nil, tags: nil)
      @file_path = file_path
      @title = title
      @description = description || "" # Default to empty string if nil
      @category_id = category_id # Validation will ensure it's present

      # Handle privacy_status: default if nil, or if provided but invalid
      @privacy_status = if privacy_status.nil? || !VALID_PRIVACY_STATUSES.include?(privacy_status)
                          DEFAULT_PRIVACY_STATUS
                        else
                          privacy_status
                        end
      @tags = tags || DEFAULT_TAGS

      validate!
    end

    def to_s
      "VideoDetails(title: '#{@title}', privacy: '#{@privacy_status}')"
    end

    # Returns a string representation suitable for logging, including class name, object_id, and instance variables.
    def inspect
      vars = instance_variables.map do |var|
        "#{var}=#{instance_variable_get(var).inspect}"
      end.join(", ")
      "#<#{self.class.name}:0x#{object_id.to_s(16)} #{vars}>"
    end

    private

    def validate!
      # Essential Validations
      if @file_path.nil? || @file_path.strip.empty?
        raise ArgumentError, "File path cannot be blank. Got: '#{@file_path.inspect}'"
      end
      if @title.nil? || @title.strip.empty?
        raise ArgumentError, "Title cannot be blank. Got: '#{@title.inspect}'"
      end
      if @category_id.nil? || @category_id.to_s.strip.empty? # Allow integer or string for category_id
        raise ArgumentError, "Category ID cannot be blank. Got: '#{@category_id.inspect}'"
      end
      @category_id = @category_id.to_s # Ensure category_id is a string after validation

      # Privacy status is already defaulted if invalid or nil, so this check is more of an assertion.
      # However, if we didn't default it in initialize, this would be the place to raise an error.
      # For now, we ensure it's one of the valid ones after defaulting.
      unless VALID_PRIVACY_STATUSES.include?(@privacy_status)
        # This should not be reached if defaulting logic in initialize is correct
        raise ArgumentError, "Internal error: Privacy status '#{@privacy_status}' is invalid despite defaulting. Allowed: #{VALID_PRIVACY_STATUSES.join(', ')}"
      end

      # Tags validation
      unless @tags.is_a?(Array)
        raise ArgumentError, "Tags must be an array. Got: '#{@tags.class}'"
      end
      if @tags.any? { |tag| !tag.is_a?(String) }
        raise ArgumentError, "All tags must be strings. Got: '#{@tags.inspect}'"
      end
    end
  end
end
