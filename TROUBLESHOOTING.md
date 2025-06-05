# Troubleshooting Guide

This guide provides solutions to common issues and debugging steps for the YouTube Uploader CLI.

## Common Issues

### Issue: Error when listing videos: "unknown keyword: :my_videos"
- **Symptom**: When running `ruby bin/youtube_upload list`, the program fails with an error message similar to "ArgumentError: unknown keyword: :my_videos".
- **Cause**: This was due to an incorrect parameter being used for the YouTube Data API in the `list_videos` method. The parameter `my_videos: true` was used instead of the correct `mine: true`.
- **Solution**: This issue has been fixed in recent versions of the script. If you encounter this, ensure your script is up-to-date. The fix involves changing `my_videos: true` to `mine: true` in the `list_videos` method within the `youtube_uploader_cli/app/gateways/cli_youtube_service_gateway.rb` file.

### Issues with Listing Videos (`youtube_upload list`) - Post-Refactor

If you encounter problems with the `youtube_upload list` command after recent updates, refer to these points. These supersede the older "unknown keyword: :my_videos" issue for current versions.

#### 1. Symptom: API Error - `missingRequiredParameter: No filter selected. Expected one of: myRating, id, chart`
*   **Context**: This error might have occurred during earlier development stages or if the code was manually altered in a way that removed the necessary API call parameters.
*   **Cause**: The YouTube Data API's `videos.list` endpoint (which was initially used) requires a specific filter. The direct `mine=true` parameter, while correct for the API's logic, was not supported as a keyword by the Ruby client library's `list_videos` method.
*   **Current Solution**: The application has been significantly refactored to list videos by:
    1.  First, fetching the authenticated user's unique "uploads" playlist ID via the `channels.list` API endpoint (using `mine: true`, which *is* supported here).
    2.  Then, retrieving video details from this specific playlist using the `playlistItems.list` API endpoint.
    This two-step process correctly targets the user's own videos and uses supported methods of the client library. If you see this error, it implies a regression or modification away from this current two-step approach.

#### 2. Symptom: Ruby Error - `ArgumentError: unknown keyword: :mine` when calling `service.list_videos`
*   **Context**: This error was encountered during development when attempting to use `mine: true` as a direct keyword argument with the `service.list_videos` method.
*   **Cause**: The version of the `google-apis-youtube_v3` Ruby client library in use does not define `mine` as a keyword argument for its `list_videos` method.
*   **Resolution**: This direct approach was abandoned. The current solution (fetching uploads playlist via `channels.list` and then items via `playlistItems.list`) avoids this issue by using methods and parameters supported by the client library.

#### 3. Symptom: Output shows `\#{index + 1}. \#{video.title}...` instead of actual video data
*   **Cause**: A formatting issue in the command-line display logic within `Cli::Main#list`. Unnecessary backslash characters (`\`) were escaping the `#{...}` Ruby string interpolation sequences, causing them to be printed literally.
*   **Solution**: This has been corrected by removing the errant backslashes in the `puts` statement. The application should now display video details correctly. If you encounter this, ensure you have the latest version of `youtube_uploader_cli/app/cli/main.rb`.

### Issue: Authentication Problems (`youtube_upload auth`)
- **Symptom**: Difficulty authenticating with Google, errors related to `client_secret.json` or `tokens.yaml`, or messages like "Authentication failed: Consent denied by user," "Could not connect to Google services," or "Invalid grant."
- **Solution**:
    - **Valid `client_secret.json`**: Ensure `client_secret.json` is correctly placed. By default, this is in `youtube_uploader_cli/config/client_secret.json`. This path can be configured by the `GOOGLE_CLIENT_SECRET_PATH` environment variable. This file must be downloaded from your Google Cloud Console for your specific OAuth 2.0 "Desktop app" client.
    - **Token File**: The application stores authentication tokens in the file specified by `YOUTUBE_TOKENS_PATH` (default: `youtube_uploader_cli/config/tokens.yaml`). If you suspect corrupted tokens, try deleting this file and re-running `youtube_upload auth` to start the authentication process from scratch.
    - **Google Cloud Console Configuration**:
        - Verify the "YouTube Data API v3" is enabled in your Google Cloud Project.
        - Ensure your OAuth 2.0 Consent Screen is configured correctly with the necessary scopes (e.g., `https://www.googleapis.com/auth/youtube.upload`).
    - **Network Issues**: For errors like "Could not connect to Google services," check your internet connection.
    - **Re-run Authentication**: Try running `youtube_upload auth` again, carefully following the on-screen prompts.

### Issue: Video Upload Failures (`youtube_upload upload ...`)
- **Symptom**: The `upload` command fails to upload the video, displaying errors like "Video file not found," "Upload failed: The file type is not supported," "Invalid category ID," "Invalid privacy status," or "Authentication required."
- **Solution**:
    - **File Path**: Double-check that the video `FILE_PATH` provided to the `upload` command is correct and the file exists.
    - **File Format**: Ensure the video file is in a format supported by YouTube.
    - **Invalid Options**:
        - **Category ID**: If providing a category ID (`-c`), ensure it's a valid numeric ID recognized by YouTube.
        - **Privacy Status**: For privacy status (`-p`), use one of the allowed values: `public`, `private`, or `unlisted`.
    - **Authentication**:
        - If you see "Authentication required," run `youtube_upload auth` first.
        - If tokens are expired or invalid (which might result in API errors), re-authenticate using `youtube_upload auth`.
    - **Consult CSV Audit Log**: The application maintains a CSV log of upload attempts (default: `logs/upload_log.csv`, configurable via `YOUTUBE_LOG_FILE_PATH` or `--log-path`). This log contains `status` ('SUCCESS' or 'FAILURE') and `details` (Video ID or error message) which can provide specific error information.

## Debugging Steps

- **Enable Verbose Application Logging**:
    - Set the `YOUTUBE_UPLOADER_LOG_LEVEL` environment variable in your `.env` file to `DEBUG` for the most detailed output:
      ```
      YOUTUBE_UPLOADER_LOG_LEVEL=DEBUG
      ```
    - Application logs are sent to STDOUT (your console) and include timestamps and severity. This provides insight into gateway operations, API calls, and use case execution.

- **Check Environment Variables**:
    - Ensure you have a `.env` file in the `youtube_uploader_cli/` directory. If not, copy it from `.env.example` and customize it.
    - Verify paths like `GOOGLE_CLIENT_SECRET_PATH` and `YOUTUBE_TOKENS_PATH` are correctly set.
    - The `YOUTUBE_APP_NAME` is also used for API requests.

- **Examine Audit Logs**:
    - For upload-specific issues, the CSV log (default: `logs/upload_log.csv`) is invaluable. It records video title, file path, YouTube URL (on success), upload date, status, and details (Video ID or error).

- **Run with `DEBUG=true` (if applicable)**:
    - Some older CLI versions or specific modules might output more information if `ENV['DEBUG'] == 'true'`. While `YOUTUBE_UPLOADER_LOG_LEVEL=DEBUG` is the primary method, this could be a secondary check for certain components.

## Other Potential Issues

- **Dependency Problems**:
    - **Symptom**: Errors related to missing gems or incorrect gem versions.
    - **Solution**: Ensure you have run `bundle install` after cloning the repository or pulling new changes. If issues persist, you might need to manage Ruby versions (e.g., using rvm or rbenv) or resolve gem conflicts, potentially by updating Bundler (`gem install bundler`) and re-running `bundle install`.
- **Google API Client Issues**:
    - **Symptom**: Errors originating directly from the `google-api-client` gem, often related to API request construction or response handling.
    - **Solution**:
        - Check the detailed logs (`YOUTUBE_UPLOADER_LOG_LEVEL=DEBUG`) for the exact error message from the API.
        - Ensure your system clock is synchronized, as time discrepancies can affect SSL/TLS and API authentication.
        - The `google-api-client` gem itself might have its own debugging flags or mechanisms (e.g., `YOUTUBE_API_DEBUG_MODE` was considered in development sprints, though its final implementation status would need verification).
- **Invalid Configuration in `.env`**:
    - **Symptom**: Application fails to start or behaves unexpectedly due to misconfigured paths or values in the `.env` file.
    - **Solution**: Carefully review all paths and settings in your `.env` file, comparing them against `.env.example` for correct variable names and expected value types.
- **Video Processing Issues on YouTube's Side**:
    - **Symptom**: The CLI reports a successful upload (video ID is returned), but the video shows errors or isn't processed correctly on YouTube.
    - **Solution**: This is usually outside the CLI's control. Check the video status directly on YouTube. Issues could be due to video content, format specifics not fully compatible, or temporary YouTube processing delays.
