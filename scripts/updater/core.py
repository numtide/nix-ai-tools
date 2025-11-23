"""Core updater classes and logic."""

from collections.abc import Callable
from pathlib import Path

from . import file_ops, nix, platforms, version
from . import hash as hash_utils


class UpdaterError(Exception):
    """Base exception for updater errors."""


class BaseUpdater:
    """Base class for package updaters."""

    def __init__(self, package: str) -> None:
        """Initialize the updater.

        Args:
            package: Package name in the flake

        """
        self.package = package
        self.package_file = Path("packages") / package / "package.nix"

        if not self.package_file.exists():
            msg = f"Package file not found: {self.package_file}"
            raise UpdaterError(msg)

    def get_current_version(self) -> str:
        """Get the current version from the flake.

        Returns:
            Current version string

        """
        # Try .#package.version first (works for most packages)
        attr = f".#{self.package}.version"
        try:
            return nix.nix_eval(attr)
        except nix.NixCommandError as e:
            # Package might be platform-restricted, try common systems
            for system in [
                "x86_64-linux",
                "aarch64-linux",
                "x86_64-darwin",
                "aarch64-darwin",
            ]:
                try:
                    attr = f".#packages.{system}.{self.package}.version"
                    return nix.nix_eval(attr)
                except nix.NixCommandError:
                    continue
            # If all systems fail, raise error from original exception
            msg = f"Could not find package {self.package} in any system"
            raise UpdaterError(msg) from e

    def update(self) -> bool:
        """Perform the update.

        Returns:
            True if update was performed, False if already up-to-date

        Raises:
            UpdaterError: If update fails

        """
        msg = "Subclasses must implement update()"
        raise NotImplementedError(msg)


class SimplePackageUpdater(BaseUpdater):
    """Updater for simple packages with a single source hash."""

    def __init__(
        self,
        package: str,
        version_fetcher: Callable[[], str],
        url_template: str,
    ) -> None:
        """Initialize the simple package updater.

        Args:
            package: Package name
            version_fetcher: Function that returns the latest version
            url_template: URL template with {version} placeholder

        """
        super().__init__(package)
        self.version_fetcher = version_fetcher
        self.url_template = url_template

    def update(self) -> bool:
        """Update the package.

        Returns:
            True if update was performed

        """
        current = self.get_current_version()
        latest = self.version_fetcher()

        if not version.should_update(current, latest):
            return False

        # Calculate new hash
        url = self.url_template.format(version=latest)
        new_hash = hash_utils.calculate_url_hash(url)

        # Update file
        file_ops.update_version(self.package_file, current, latest)
        file_ops.update_hash(self.package_file, "hash", new_hash)
        file_ops.update_url(self.package_file, current, latest)

        return True


class MultiPlatformUpdater(BaseUpdater):
    """Updater for packages with multiple platform-specific binaries."""

    def __init__(
        self,
        package: str,
        version_fetcher: Callable[[], str],
        url_template: str,
        *,
        platforms_list: list[platforms.Platform] | None = None,
        platform_to_url_arch: Callable[[platforms.Platform], str] | None = None,
    ) -> None:
        """Initialize the multi-platform updater.

        Args:
            package: Package name
            version_fetcher: Function that returns the latest version
            url_template: URL template with {version} and {platform} placeholders
            platforms_list: List of platforms to update (default: all platforms)
            platform_to_url_arch: Function to convert Platform to URL arch string

        """
        super().__init__(package)
        self.version_fetcher = version_fetcher
        self.url_template = url_template
        self.platforms_list = platforms_list or platforms.ALL_PLATFORMS
        self.platform_to_url_arch = platform_to_url_arch or (lambda p: p.value)

    def update(self) -> bool:
        """Update the package.

        Returns:
            True if update was performed

        """
        current = self.get_current_version()
        latest = self.version_fetcher()

        if not version.should_update(current, latest):
            return False

        # Update version first
        file_ops.update_version(self.package_file, current, latest)
        file_ops.update_url(self.package_file, current, latest)

        # Update hashes for each platform
        for plat in self.platforms_list:
            url_arch = self.platform_to_url_arch(plat)
            url = self.url_template.format(version=latest, platform=url_arch)

            try:
                new_hash = hash_utils.calculate_url_hash(url)
                file_ops.update_platform_hash(self.package_file, plat.value, new_hash)
            except (nix.NixCommandError, ValueError):
                pass
                # Continue with other platforms

        return True


class NpmPackageUpdater(SimplePackageUpdater):
    """Updater for npm packages with npmDepsHash."""

    def __init__(
        self,
        package: str,
        npm_package_name: str,
        *,
        has_npm_deps_hash: bool = True,
    ) -> None:
        """Initialize npm package updater.

        Args:
            package: Nix package name
            npm_package_name: npm package name
            has_npm_deps_hash: Whether package has npmDepsHash to update

        """
        # Handle scoped npm packages (@scope/package)
        # URL format: https://registry.npmjs.org/@scope/package/-/package-version.tgz
        if npm_package_name.startswith("@"):
            # Extract unscoped name for the filename part
            unscoped_name = npm_package_name.split("/", 1)[1]
            url_template = f"https://registry.npmjs.org/{npm_package_name}/-/{unscoped_name}-{{version}}.tgz"
        else:
            url_template = f"https://registry.npmjs.org/{npm_package_name}/-/{npm_package_name}-{{version}}.tgz"

        super().__init__(
            package=package,
            version_fetcher=lambda: version.fetch_npm_version(npm_package_name),
            url_template=url_template,
        )
        self.npm_package_name = npm_package_name
        self.has_npm_deps_hash = has_npm_deps_hash

    def update(self) -> bool:
        """Update the npm package.

        Returns:
            True if update was performed

        """
        # First do the basic update
        if not super().update():
            return False

        # Then update npmDepsHash if needed
        if self.has_npm_deps_hash:
            try:
                npm_deps_hash = hash_utils.get_npm_deps_hash(
                    self.package,
                    self.package_file,
                )
                file_ops.update_hash(self.package_file, "npmDepsHash", npm_deps_hash)
            except (nix.NixCommandError, ValueError):
                pass

        return True
