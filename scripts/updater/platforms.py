"""Platform definitions and multi-platform support utilities."""

from collections.abc import Callable
from enum import Enum
from typing import Optional


class Platform(str, Enum):
    """Supported Nix platforms."""

    X86_64_LINUX = "x86_64-linux"
    AARCH64_LINUX = "aarch64-linux"
    X86_64_DARWIN = "x86_64-darwin"
    AARCH64_DARWIN = "aarch64-darwin"

    @property
    def arch(self) -> str:
        """Get the architecture part of the platform."""
        return self.value.split("-")[0]

    @property
    def os(self) -> str:
        """Get the OS part of the platform."""
        return self.value.split("-")[1]

    def to_rust_target(self) -> str:
        """Convert to Rust target triple format.

        Returns:
            Rust target triple (e.g., "x86_64-unknown-linux-gnu")

        """
        mapping = {
            Platform.X86_64_LINUX: "x86_64-unknown-linux-gnu",
            Platform.AARCH64_LINUX: "aarch64-unknown-linux-gnu",
            Platform.X86_64_DARWIN: "x86_64-apple-darwin",
            Platform.AARCH64_DARWIN: "aarch64-apple-darwin",
        }
        return mapping[self]

    def to_go_arch(self) -> str:
        """Convert to Go GOARCH format.

        Returns:
            Go architecture name (e.g., "amd64", "arm64")

        """
        arch_mapping = {
            "x86_64": "amd64",
            "aarch64": "arm64",
        }
        return arch_mapping[self.arch]

    def to_go_os(self) -> str:
        """Convert to Go GOOS format.

        Returns:
            Go OS name (e.g., "linux", "darwin")

        """
        return self.os

    def to_npm_arch(self) -> str:
        """Convert to npm/Node.js architecture format.

        Returns:
            npm architecture name (e.g., "x64", "arm64")

        """
        arch_mapping = {
            "x86_64": "x64",
            "aarch64": "arm64",
        }
        return arch_mapping[self.arch]

    def to_npm_platform(self) -> str:
        """Convert to npm/Node.js platform format.

        Returns:
            npm platform name (e.g., "linux", "darwin")

        """
        return self.os

    @classmethod
    def from_rust_target(cls, target: str) -> Optional["Platform"]:
        """Parse from Rust target triple.

        Args:
            target: Rust target triple (e.g., "x86_64-unknown-linux-gnu")

        Returns:
            Platform enum or None if not recognized

        """
        mapping = {
            "x86_64-unknown-linux-gnu": cls.X86_64_LINUX,
            "aarch64-unknown-linux-gnu": cls.AARCH64_LINUX,
            "x86_64-apple-darwin": cls.X86_64_DARWIN,
            "aarch64-apple-darwin": cls.AARCH64_DARWIN,
        }
        return mapping.get(target)


# Common platform groups
ALL_PLATFORMS = list(Platform)


def make_platform_mapper(
    arch_names: dict[str, str],
    os_names: dict[str, str],
    *,
    separator: str = "-",
    os_first: bool = True,
) -> Callable[[Platform], str]:
    """Create a platform-to-vendor-arch mapper function.

    This helper eliminates repetitive platform mapping boilerplate.

    Args:
        arch_names: Map from standard arch names to vendor-specific names
                   (e.g., {"x86_64": "amd64", "aarch64": "arm64"})
        os_names: Map from standard OS names to vendor-specific names
                 (e.g., {"linux": "linux", "darwin": "macos"})
        separator: String separating OS and arch (default: "-")
        os_first: Whether OS comes before arch (default: True)

    Returns:
        Function that converts Platform to vendor-specific string

    Examples:
        >>> # For Go-style: linux-amd64, darwin-arm64
        >>> mapper = make_platform_mapper(
        ...     {"x86_64": "amd64", "aarch64": "arm64"},
        ...     {"linux": "linux", "darwin": "darwin"},
        ... )
        >>> mapper(Platform.X86_64_LINUX)
        'linux-amd64'

        >>> # For npm-style: x64-linux, arm64-darwin
        >>> mapper = make_platform_mapper(
        ...     {"x86_64": "x64", "aarch64": "arm64"},
        ...     {"linux": "linux", "darwin": "darwin"},
        ...     os_first=False,
        ... )
        >>> mapper(Platform.AARCH64_DARWIN)
        'arm64-darwin'

        >>> # For path-style: linux/x64
        >>> mapper = make_platform_mapper(
        ...     {"x86_64": "x64", "aarch64": "arm64"},
        ...     {"linux": "linux", "darwin": "darwin"},
        ...     separator="/",
        ... )

    """

    def mapper(platform: Platform) -> str:
        arch = arch_names[platform.arch]
        os = os_names[platform.os]
        return f"{os}{separator}{arch}" if os_first else f"{arch}{separator}{os}"

    return mapper
