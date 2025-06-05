# Feature: List YouTube Videos

This document describes the `list` command for the YouTube Uploader CLI, which allows users to list videos from their YouTube account.

## Command Usage

The command to list videos is:

```bash
youtube_upload list [options]
```

### Options

*   `-m, --max-results NUMBER`: Specifies the maximum number of videos to retrieve. The default is 10, and the maximum allowed by the YouTube API is typically 50.
*   `-h, --help`: Displays help information for the `list` command.

## Functionality

The `list` command performs the following actions:

1.  **Authentication**: It first attempts to authenticate the user with Google using existing credentials stored during the `auth` command. If authentication fails or credentials are not found, it will guide the user through the OAuth 2.0 process (as handled by the `authenticate` method in the gateway, which might involve prompting the user to open a URL and paste a code).
2.  **Fetch Videos**: Once authenticated, it calls the YouTube Data API v3 to retrieve a list of videos uploaded by the authenticated user.
3.  **Display Videos**: The command then prints a list of the retrieved videos to the console, including:
    *   A sequential number.
    *   The video title.
    *   The YouTube URL for the video.
    *   The date the video was published.

## Example

To list the latest 5 videos from your account:

```bash
youtube_upload list --max-results 5
```

### Example Output:

```
Authenticating...
Authentication successful.
Fetching video list...
Your Videos:
1. My Awesome Trip - https://www.youtube.com/watch?v=VIDEO_ID_1 (Published: 2023-10-26)
2. Cooking Adventures - https://www.youtube.com/watch?v=VIDEO_ID_2 (Published: 2023-10-20)
# ... and so on
```

## Error Handling

*   If authentication fails, an error message will be displayed, and the command will terminate.
*   If an error occurs while fetching videos from the YouTube API (e.g., quota issues, network problems), an error message will be displayed.
*   If no videos are found on the account, a message indicating this will be shown.

```
