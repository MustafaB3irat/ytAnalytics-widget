"""
OAuth handler for YouTube Analytics API.
Manages the initial OAuth flow and automatic token refresh.
"""

import os
import json
from pathlib import Path
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request


def get_credentials(config: dict) -> Credentials:
    """
    Load existing credentials or run the OAuth flow to get new ones.
    Tokens are saved locally so the user only authenticates once.
    """
    oauth_config = config.get("oauth", {})
    scopes = oauth_config.get("scopes", [])
    credentials_file = Path(oauth_config.get("credentials_file", "credentials/client_secret.json"))
    token_file = Path(oauth_config.get("token_file", "credentials/token.json"))

    creds = None

    # Load saved token if it exists
    if token_file.exists():
        creds = Credentials.from_authorized_user_file(str(token_file), scopes)

    # If no valid credentials, run OAuth flow or refresh
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("🔄 Refreshing access token...")
            creds.refresh(Request())
        else:
            if not credentials_file.exists():
                raise FileNotFoundError(
                    f"\n❌ OAuth credentials not found at: {credentials_file}\n"
                    "Please follow the setup guide in docs/SETUP.md to create your "
                    "Google Cloud project and download client_secret.json.\n"
                )
            print("🔐 Starting OAuth flow — your browser will open...")
            flow = InstalledAppFlow.from_client_secrets_file(
                str(credentials_file), scopes
            )
            creds = flow.run_local_server(port=0)
            print("✅ Authentication successful!")

        # Save token for next run
        token_file.parent.mkdir(parents=True, exist_ok=True)
        with open(token_file, "w") as f:
            f.write(creds.to_json())
        print(f"💾 Token saved to {token_file}")

    return creds
