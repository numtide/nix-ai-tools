"""HTTP utilities for fetching data from URLs."""

import json
import urllib.request
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
