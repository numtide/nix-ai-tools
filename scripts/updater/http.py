"""HTTP utilities for fetching data from URLs."""

import json
import os
import urllib.request
from typing import Any


def _github_request(url: str) -> urllib.request.Request:
    """Build an authenticated GitHub API request.

    Uses the GITHUB_TOKEN environment variable so that CI jobs don't hit
    the unauthenticated rate limit (60 req/h → 5 000 req/h).
    """
    req = urllib.request.Request(url)
    token = os.environ.get("GITHUB_TOKEN", "")
    if token:
        req.add_header("Authorization", f"token {token}")
    return req


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
    target: str | urllib.request.Request = url
    if "api.github.com" in url:
        target = _github_request(url)
    with urllib.request.urlopen(target, timeout=timeout) as response:
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
