#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.error

def main():
    token = os.environ.get('DISCORD_BOT_TOKEN')
    channel_id = os.environ.get('DISCORD_CHANNEL_ID', '1516746684070101096') # Default to announcements channel
    version = os.environ.get('RELEASE_VERSION', 'New Version')

    if not token:
        print("Error: DISCORD_BOT_TOKEN environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    # Read changelog from stdin
    changelog = sys.stdin.read().strip()
    
    if not changelog:
        print("Warning: No changelog content received.", file=sys.stderr)
        sys.exit(0)

    # Discord embeds can have up to 4096 characters in the description
    if len(changelog) > 4096:
        changelog = changelog[:4093] + "..."

    embeds = [
        {
            "title": f"🚀 Tracelet Release {version}",
            "description": changelog,
            "color": 3447003,  # Blue color
            "url": "https://pub.dev/packages/tracelet",
            "footer": {
                "text": "Powered by Ikolvi"
            }
        }
    ]

    payload = {
        "embeds": embeds
    }

    url = f"https://discord.com/api/v10/channels/{channel_id}/messages"
    req = urllib.request.Request(url, method="POST")
    req.add_header("Authorization", f"Bot {token}")
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", "Tracelet-GitHubAction (https://github.com/Ikolvi/Tracelet, 1.0.0)")

    data = json.dumps(payload).encode("utf-8")

    try:
        with urllib.request.urlopen(req, data=data) as response:
            if response.status in (200, 201):
                print("Successfully posted release to Discord.")
            else:
                print(f"Failed to post to Discord. Status: {response.status}", file=sys.stderr)
                sys.exit(1)
    except urllib.error.HTTPError as e:
        print(f"HTTPError posting to Discord: {e.code} {e.reason}", file=sys.stderr)
        print(e.read().decode('utf-8'), file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"URLError posting to Discord: {e.reason}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
