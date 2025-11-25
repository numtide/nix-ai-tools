"""HTTP utilities for fetching data from URLs."""

import json
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def fetch_text(url: str, *, timeout: int = 30) -> str:
    """Fetch text content from a URL.

    Args:
        url: URL to fetch
        timeout: Request timeout in seconds

    Returns:
        Response body as text

    Raises:
        urllib.error.URLError: If the request fails

    """
    with urllib.request.urlopen(url, timeout=timeout) as response:
        data: bytes = response.read()
        return data.decode("utf-8")


def fetch_json(url: str, *, timeout: int = 30) -> dict[str, Any] | list[Any]:
    """Fetch and parse JSON from a URL.

    Args:
        url: URL to fetch
        timeout: Request timeout in seconds

    Returns:
        Parsed JSON data (dict or list)

    Raises:
        urllib.error.URLError: If the request fails
        json.JSONDecodeError: If response is not valid JSON

    """
    text = fetch_text(url, timeout=timeout)
    result: dict[str, Any] | list[Any] = json.loads(text)
    return result


def download_file(url: str, path: Path, *, timeout: int = 300) -> None:
    """Download a file from a URL.

    Args:
        url: URL to download from
        path: Destination file path
        timeout: Request timeout in seconds

    Raises:
        urllib.error.URLError: If the request fails

    """
    with urllib.request.urlopen(url, timeout=timeout) as response:
        path.write_bytes(response.read())


def check_url_accessible(url: str, *, timeout: int = 10) -> bool:
    """Check if a URL is accessible.

    Args:
        url: URL to check
        timeout: Request timeout in seconds

    Returns:
        True if URL is accessible (returns 200 OK)

    """
    try:
        # Make a HEAD request to check accessibility without downloading content
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=timeout):
            return True
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        return False
