# Project Backlog: YouTube Uploader CLI

This document tracks potential features, improvements, and bug fixes for the YouTube Uploader CLI.

## ✨ Features

These are new capabilities or significant enhancements to existing functionality.

*   **F001: Web UI for Video Management**
    *   Description: Develop a Rails-based web user interface for uploading, viewing, and managing video details. (Derived from README "Future: Rails UI")
    *   Priority: High
*   **F002: Edit Uploaded Video Details**
    *   Description: Allow users to modify the title, description, privacy status, tags, and category of a video already uploaded to YouTube via the CLI.
    *   Priority: Medium
*   **F003: Delete Uploaded Video**
    *   Description: Enable users to delete a video from YouTube that was previously uploaded using the CLI.
    *   Priority: Medium
*   **F004: List Uploaded Videos**
    *   Description: Provide a command to list all videos uploaded by the authenticated user via this tool, showing basic info like title, video ID, upload date, and privacy status.
    *   Priority: Medium
*   **F005: Support for YouTube Playlists**
    *   Description: Allow users to add an uploaded video to an existing YouTube playlist or create a new playlist and add the video to it.
    *   Priority: Low
*   **F006: Batch Video Uploads**
    *   Description: Support uploading all videos from a specified directory, potentially with options to apply common metadata or derive metadata from filenames.
    *   Priority: Medium
*   **F007: Custom Thumbnail Upload**
    *   Description: Allow users to specify a custom image file to be used as the thumbnail for the uploaded video.
    *   Priority: Medium
*   **F008: Check Video Processing Status**
    *   Description: After an upload is initiated, provide a way to check the processing status of the video on YouTube (e.g., "processing", "succeeded", "failed").
    *   Priority: Low
*   **F009: Database Persistence for Logs - PostgreSQL**
    *   Description: Implement a gateway to store upload log entries in a PostgreSQL database. (Derived from README "Future: Database Adapters")
    *   Priority: Medium
*   **F010: Database Persistence for Logs - MySQL**
    *   Description: Implement a gateway to store upload log entries in a MySQL database. (Derived from README "Future: Database Adapters")
    *   Priority: Low
*   **F011: Scheduled Video Publishing**
    *   Description: Allow users to specify a future date/time for the video to become public.
    *   Priority: Low
*   **F012: Manage Video Comments**
    *   Description: Basic functionality to list, reply to, or delete comments on videos uploaded via the CLI.
    *   Priority: Low
*   **F013: Basic Video Analytics**
    *   Description: Allow users to fetch and display basic analytics (view count, likes) for their uploaded videos.
    *   Priority: Low

## ⚙️ Chores

These are tasks to improve the codebase, development process, or maintainability.

*   **C001: Enhanced Error Handling and Reporting**
    *   Description: Implement more specific error codes and user-friendly messages for CLI outputs. Standardize error responses.
    *   Priority: High
*   **C002: Structured Logging**
    *   Description: Implement structured logging (e.g., JSON format to a dedicated log file) for better audit trails and easier debugging, supplementing the current user-facing log.
    *   Priority: Medium
*   **C003: Refactor LogPersistenceGateway for Extensibility**
    *   Description: Refactor the `LogPersistenceGateway` to more easily accommodate different backend storage solutions (e.g., CSV, PostgreSQL, MySQL).
    *   Priority: Medium
*   **C004: Update Dependencies**
    *   Description: Regularly review and update all gem dependencies (e.g., `google-api-client`, `thor`) to their latest stable and secure versions.
    *   Priority: Medium
*   **C005: Increase Test Coverage**
    *   Description: Write more unit and integration tests, especially for gateway implementations, error conditions, and various CLI options.
    *   Priority: Medium
*   **C006: Configuration for Default Upload Options**
    *   Description: Allow users to set default video upload options (e.g., default privacy status, common tags, default category) via a user-specific configuration file (e.g., `~/.youtube_uploader_cli/config.yml`) or environment variables.
    *   Priority: Medium
*   **C007: Add CI/CD Pipeline**
    *   Description: Set up a Continuous Integration/Continuous Deployment pipeline (e.g., using GitHub Actions) for automated testing, linting, and potentially building releases.
    *   Priority: Medium
*   **C008: Interactive Upload Progress**
    *   Description: For the `upload` command, display a progress bar or more detailed feedback during the video file upload process.
    *   Priority: Low
*   **C009: Shell Autocompletion Scripts**
    *   Description: Generate and provide installation instructions for shell autocompletion scripts (e.g., for Bash, Zsh) to improve CLI usability.
    *   Priority: Low
*   **C010: Containerize Application (Docker)**
    *   Description: Create a Dockerfile and necessary configurations to allow running the CLI application within a Docker container for consistent environments and easier distribution.
    *   Priority: Low
*   **C011: Expand README Documentation**
    *   Description: Add more examples and detailed explanations for each command and feature in the `README.md`.
    *   Priority: Low
*   **C012: Automated UI Tests for Web UI**
    *   Description: If the Rails Web UI (Feature F001) is implemented, add a suite of automated UI tests (e.g., using Capybara/Selenium).
    *   Priority: Conditional (on F001)

## 🐞 Bugs

This section is for tracking identified bugs. Currently, no bugs are tracked. New bugs will be added here as they are discovered.

*   (No bugs reported yet)
