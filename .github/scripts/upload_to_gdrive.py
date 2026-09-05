#!/usr/bin/env python3
"""Upload an APK to Google Drive using OAuth refresh-token credentials."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def require(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        print(f"::error::Missing repository secret: {name}")
        sys.exit(1)
    return value


def http_request(
    method: str,
    url: str,
    *,
    data=None,
    headers=None,
    form: bool = False,
):
    body = data
    req_headers = dict(headers or {})
    if form and data is not None:
        body = urllib.parse.urlencode(data).encode()
        req_headers.setdefault(
            "Content-Type", "application/x-www-form-urlencoded"
        )
    request = urllib.request.Request(
        url, data=body, headers=req_headers, method=method
    )
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def main() -> None:
    client_id = require("GOOGLE_CLIENT_ID")
    client_secret = require("GOOGLE_CLIENT_SECRET")
    refresh_token = require("GOOGLE_REFRESH_TOKEN")
    folder_id = require("GDRIVE_FOLDER_ID")
    apk_name = require("APK_NAME")

    if not os.path.isfile(apk_name):
        print(f"::error::APK not found: {apk_name}")
        sys.exit(1)

    status, token_raw = http_request(
        "POST",
        "https://oauth2.googleapis.com/token",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        },
        form=True,
    )
    token_data = json.loads(token_raw.decode() or "{}")
    access_token = token_data.get("access_token")
    if status >= 300 or not access_token:
        print("::error::Failed to refresh Google access token")
        print(token_data)
        sys.exit(1)

    auth = {"Authorization": f"Bearer {access_token}"}
    query = f"name='{apk_name}' and '{folder_id}' in parents and trashed=false"
    list_url = (
        "https://www.googleapis.com/drive/v3/files?"
        + urllib.parse.urlencode(
            {"q": query, "fields": "files(id,name)", "spaces": "drive"}
        )
    )
    status, list_raw = http_request("GET", list_url, headers=auth)
    list_data = json.loads(list_raw.decode() or "{}")
    if status >= 300:
        print("::error::Failed to list Drive folder")
        print(list_data)
        sys.exit(1)

    files = list_data.get("files") or []
    existing_id = files[0]["id"] if files else None
    with open(apk_name, "rb") as handle:
        apk_bytes = handle.read()

    if existing_id:
        print(f"Updating existing Drive file id={existing_id}")
        upload_url = (
            "https://www.googleapis.com/upload/drive/v3/files/"
            f"{existing_id}?uploadType=media"
        )
        status, resp_raw = http_request(
            "PATCH",
            upload_url,
            data=apk_bytes,
            headers={
                **auth,
                "Content-Type": "application/vnd.android.package-archive",
            },
        )
    else:
        print(f"Creating new Drive file in folder {folder_id}")
        metadata = json.dumps({"name": apk_name, "parents": [folder_id]}).encode()
        boundary = b"sms_forwarder_apk_boundary"
        body = (
            b"--"
            + boundary
            + b"\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n"
            + metadata
            + b"\r\n--"
            + boundary
            + b"\r\nContent-Type: application/vnd.android.package-archive\r\n\r\n"
            + apk_bytes
            + b"\r\n--"
            + boundary
            + b"--\r\n"
        )
        status, resp_raw = http_request(
            "POST",
            "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
            data=body,
            headers={
                **auth,
                "Content-Type": (
                    f"multipart/related; boundary={boundary.decode()}"
                ),
            },
        )

    resp_data = json.loads(resp_raw.decode() or "{}")
    if status < 200 or status >= 300:
        print(f"::error::Google Drive upload failed (HTTP {status})")
        print(resp_data)
        sys.exit(1)

    print(f"Uploaded: name={resp_data.get('name')} id={resp_data.get('id')}")


if __name__ == "__main__":
    main()
