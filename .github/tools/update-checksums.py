#!/usr/bin/env python3
"""Refresh the ``source-checksum`` entries in ``snap/snapcraft.yaml``.

This runs automatically as a Renovate ``postUpgradeTask`` after Renovate
bumps a ``source:`` URL, so that every version bump also carries a valid
checksum. It can also be run by hand:

    .github/tools/update-checksums.py [path/to/snapcraft.yaml]

Only remote sources whose URL differs from HEAD are downloaded and hashed, so
a bump costs a single artifact download instead of re-hashing every component
(pass ``--all`` to re-hash every remote source).

The YAML is parsed structurally with ruamel.yaml, so a ``source-checksum:``
that appears before its ``source:`` (or anywhere else in the same part) is
handled correctly, unlike a line-based grep/awk approach. The file itself is
edited surgically at the exact positions ruamel reports, so comments,
indentation and everything else in the file stay byte-for-byte identical.

Dependencies beyond the standard library: ``ruamel.yaml``. If it is missing,
the script tries to install it into the user site-packages before giving up.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, NamedTuple, Optional

# Mirrors the previous bash implementation: per-connection timeout, limited
# retries, and a hard cap on the total transfer time so a stalled download
# cannot wedge the Renovate run.
CONNECT_TIMEOUT_SECONDS = 30
MAX_DOWNLOAD_SECONDS = 30 * 60
DOWNLOAD_RETRIES = 3
RETRY_DELAY_SECONDS = 5
CHUNK_SIZE = 1 << 20  # 1 MiB
USER_AGENT = "nextcloud-snap-update-checksums (+https://github.com/nextcloud-snap/nextcloud-snap)"


class ChecksumUpdateError(Exception):
    """A problem that should fail the run (and the Renovate artifact update)."""


def load_yaml_class() -> Any:
    """Import ruamel.yaml, installing it into the user site if needed."""
    try:
        from ruamel.yaml import YAML

        return YAML
    except ImportError:
        pass

    print(
        "ruamel.yaml is not installed; trying to install it with pip...",
        file=sys.stderr,
    )
    attempts = [
        # Normal case (the Renovate container, most developer machines).
        [sys.executable, "-m", "pip", "install", "--quiet", "--user", "ruamel.yaml"],
        # PEP 668 "externally managed" distributions (e.g. recent Debian /
        # Ubuntu) refuse plain pip installs into the user site as well.
        [
            sys.executable,
            "-m",
            "pip",
            "install",
            "--quiet",
            "--user",
            "--break-system-packages",
            "ruamel.yaml",
        ],
        # Some minimal Python builds ship without pip; bootstrap it once.
        [sys.executable, "-m", "ensurepip", "--user"],
        [sys.executable, "-m", "pip", "install", "--quiet", "--user", "ruamel.yaml"],
    ]
    for attempt in attempts:
        try:
            subprocess.run(attempt, check=True)
            break
        except (subprocess.CalledProcessError, FileNotFoundError) as exc:
            print(f"warning: {' '.join(attempt[2:])} failed: {exc}", file=sys.stderr)
    else:
        raise ChecksumUpdateError(
            "ruamel.yaml is required but could not be installed "
            "automatically. Install it manually, e.g. "
            "'python3 -m pip install ruamel.yaml' or "
            "'apt install python3-ruamel.yaml'."
        )

    import importlib

    importlib.invalidate_caches()
    try:
        from ruamel.yaml import YAML

        return YAML
    except ImportError as exc:
        raise ChecksumUpdateError(
            "ruamel.yaml was installed but still cannot be imported; "
            f"check the environment ({exc})."
        ) from exc


class SourceEntry(NamedTuple):
    """One part whose ``source`` is a remote (http/https) URL."""

    part_name: str
    url: str
    checksum: Optional[str]  # raw "algorithm/digest" value, or None
    node: Any  # ruamel CommentedMap of the part (provides value line/col)


def remote_sources(doc: Any) -> list[SourceEntry]:
    """Collect every part with an http(s) ``source`` from a parsed document."""
    if not isinstance(doc, dict):
        return []
    parts = doc.get("parts")
    if not isinstance(parts, dict):
        return []

    entries = []
    for part_name, part in parts.items():
        if not isinstance(part, dict):
            continue
        url = part.get("source")
        if not isinstance(url, str):
            # Sources that are lists or mapping-based are not handled here;
            # renovate only tracks plain tarball URLs.
            continue
        if not url.startswith(("https://", "http://")):
            continue
        checksum = part.get("source-checksum")
        entries.append(
            SourceEntry(
                part_name=str(part_name),
                url=url,
                checksum=checksum if isinstance(checksum, str) else None,
                node=part,
            )
        )
    return entries


def checksum_algorithm(raw_checksum: str, *, context: str) -> str:
    """Extract and validate the algorithm of an ``algorithm/digest`` value."""
    algorithm, separator, _digest = raw_checksum.partition("/")
    if not separator or not algorithm:
        raise ChecksumUpdateError(
            f"malformed source-checksum '{raw_checksum}' for {context}; "
            "expected '<algorithm>/<digest>'"
        )
    try:
        hashlib.new(algorithm)
    except ValueError:
        raise ChecksumUpdateError(
            f"unsupported checksum algorithm '{algorithm}' for {context}"
        ) from None
    return algorithm


def urls_from_head(snapcraft_yaml: Path, yaml: Any) -> Optional[set[str]]:
    """Return the remote source URLs of the file at HEAD, or None on failure."""
    try:
        result = subprocess.run(
            ["git", "show", f"HEAD:{snapcraft_yaml.as_posix()}"],
            check=True,
            capture_output=True,
            text=True,
        )
        old_doc = yaml.load(result.stdout)
    except (subprocess.CalledProcessError, FileNotFoundError, OSError) as exc:
        print(
            f"warning: {snapcraft_yaml} is not readable from HEAD ({exc}); "
            "every remote source will be re-hashed",
            file=sys.stderr,
        )
        return None
    except Exception as exc:  # ruamel parse errors share no single base class
        print(
            f"warning: could not parse {snapcraft_yaml} from HEAD ({exc}); "
            "every remote source will be re-hashed",
            file=sys.stderr,
        )
        return None
    return {entry.url for entry in remote_sources(old_doc)}


def download(url: str, destination: Path) -> None:
    """Download ``url`` to ``destination`` with retries and a total time cap.

    curl (or wget) is preferred when available: some mirrors (notably
    dev.mysql.com) reject the TLS/HTTP fingerprint of Python's urllib, no
    matter which User-Agent is sent. The stdlib implementation remains as a
    fallback for minimal environments.
    """
    if shutil.which("curl"):
        return _download_with_curl(url, destination)
    if shutil.which("wget"):
        return _download_with_wget(url, destination)
    return _download_with_urllib(url, destination)


def _run_downloader(argv: list[str], url: str) -> None:
    """Run a download helper, never leaving an orphaned child behind.

    subprocess.run() re-raises KeyboardInterrupt without terminating the
    child, which would leak a 500MB curl download on Ctrl+C/SIGTERM. Kill and
    reap the child explicitly instead.
    """
    process = subprocess.Popen(
        argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    try:
        _stdout, stderr = process.communicate()
    except BaseException:
        process.kill()
        process.wait()
        raise
    if process.returncode != 0:
        raise ChecksumUpdateError(f"download of {url} failed: {stderr.strip()}")


def _download_with_curl(url: str, destination: Path) -> None:
    # --max-time caps the whole transfer so a stalled download cannot hang
    # the run indefinitely; --retry/--connect-timeout handle connection-level
    # hiccups (transient statuses and connection errors only, like before).
    _run_downloader(
        [
            "curl",
            "-fsSL",
            "--retry",
            str(DOWNLOAD_RETRIES),
            "--retry-delay",
            str(RETRY_DELAY_SECONDS),
            "--connect-timeout",
            str(CONNECT_TIMEOUT_SECONDS),
            "--max-time",
            str(MAX_DOWNLOAD_SECONDS),
            "-o",
            str(destination),
            url,
        ],
        url,
    )


def _download_with_wget(url: str, destination: Path) -> None:
    _run_downloader(
        [
            "wget",
            "-q",
            f"--tries={DOWNLOAD_RETRIES}",
            f"--timeout={CONNECT_TIMEOUT_SECONDS}",
            "-O",
            str(destination),
            url,
        ],
        url,
    )


def _retry_unless_permanent(exc: urllib.error.HTTPError) -> bool:
    # 4xx is almost certainly not transient; retrying is pointless.
    return not (400 <= exc.code < 500 and exc.code not in (408, 409, 425, 429))


def _download_with_urllib(url: str, destination: Path) -> None:
    last_error: Optional[BaseException] = None
    for attempt in range(1, DOWNLOAD_RETRIES + 1):
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            deadline = time.monotonic() + MAX_DOWNLOAD_SECONDS
            with urllib.request.urlopen(
                request, timeout=CONNECT_TIMEOUT_SECONDS
            ) as response, open(destination, "wb") as handle:
                while True:
                    chunk = response.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    handle.write(chunk)
                    if time.monotonic() > deadline:
                        raise TimeoutError(
                            f"download of {url} exceeded {MAX_DOWNLOAD_SECONDS}s"
                        )
            return
        except urllib.error.HTTPError as exc:
            if not _retry_unless_permanent(exc):
                raise ChecksumUpdateError(
                    f"download of {url} failed: HTTP {exc.code} {exc.reason}"
                ) from exc
            last_error = exc
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            last_error = exc

        if attempt < DOWNLOAD_RETRIES:
            print(
                f"warning: download of {url} failed (attempt "
                f"{attempt}/{DOWNLOAD_RETRIES}): {last_error}; retrying in "
                f"{RETRY_DELAY_SECONDS}s",
                file=sys.stderr,
            )
            time.sleep(RETRY_DELAY_SECONDS)

    raise ChecksumUpdateError(
        f"download of {url} failed after {DOWNLOAD_RETRIES} attempts: {last_error}"
    )


def compute_checksum(algorithm: str, path: Path) -> str:
    hasher = hashlib.new(algorithm)
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK_SIZE), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def write_back(path: Path, content: str) -> None:
    """Write ``content`` atomically, keeping the original file permissions."""
    fd, tmp_name = tempfile.mkstemp(
        dir=str(path.parent), prefix=f".{path.name}.", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
        shutil.copymode(path, tmp_name)
        os.replace(tmp_name, path)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def replace_checksum_value(
    lines: list[str], entry: SourceEntry, path: Path, new_checksum: str
) -> None:
    """Replace the checksum value in the original text at ruamel's position.

    Editing the original lines directly (instead of re-serializing the YAML
    document) guarantees that every unrelated byte in the file -- comments,
    blank lines, unusual indentation -- stays exactly as it was, which keeps
    the resulting Renovate branches free of formatting noise.
    """
    try:
        row, col = entry.node.lc.value("source-checksum")
    except (AttributeError, KeyError) as exc:
        raise ChecksumUpdateError(
            f"cannot locate the source-checksum position of part "
            f"'{entry.part_name}' ({exc}); please update it manually"
        ) from exc

    line = lines[row]
    if "source-checksum" not in line:
        raise ChecksumUpdateError(
            f"unexpected layout for the source-checksum of part "
            f"'{entry.part_name}': {path} line {row + 1} does not contain the "
            "key (multi-line values are not supported); please update it "
            "manually"
        )

    # An optional surrounding quote is preserved.
    start = col + (1 if col < len(line) and line[col] in "\"'" else 0)
    old_checksum = entry.checksum or ""
    if line[start : start + len(old_checksum)] != old_checksum:
        raise ChecksumUpdateError(
            f"unexpected layout for the source-checksum of part "
            f"'{entry.part_name}': {path} line {row + 1} does not match the "
            "parsed value; please update it manually"
        )
    lines[row] = (
        line[:start] + new_checksum + line[start + len(old_checksum) :]
    )


def graceful_shutdown(signum: int, _frame: Any) -> None:
    # Raising KeyboardInterrupt lets context managers (e.g. the temporary
    # download directory) clean up on SIGTERM/SIGHUP, just like on Ctrl+C.
    raise KeyboardInterrupt(f"received signal {signum}")


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "snapcraft_yaml",
        nargs="?",
        default="snap/snapcraft.yaml",
        type=Path,
        help="path to the snapcraft.yaml to update (default: %(default)s)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="re-hash every remote source instead of only those changed "
        "relative to HEAD",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    snapcraft_yaml: Path = args.snapcraft_yaml
    if not snapcraft_yaml.is_file():
        raise ChecksumUpdateError(f"{snapcraft_yaml} does not exist")

    yaml_class = load_yaml_class()
    yaml = yaml_class(typ="rt")  # round-trip: needed for value line/col info

    with open(snapcraft_yaml, encoding="utf-8") as handle:
        original_lines = handle.read().splitlines(keepends=True)
    try:
        doc = yaml.load("".join(original_lines))
    except Exception as exc:  # ruamel errors share no single base class
        raise ChecksumUpdateError(
            f"could not parse {snapcraft_yaml}: {exc}"
        ) from exc
    if doc is None:
        raise ChecksumUpdateError(f"{snapcraft_yaml} is empty or not YAML")

    current = remote_sources(doc)
    if not current:
        print(f"No remote sources found in {snapcraft_yaml}; nothing to do.")
        return 0

    if args.all:
        changed_urls = {entry.url for entry in current}
    else:
        old_urls = urls_from_head(snapcraft_yaml, yaml)
        if old_urls is None:
            changed_urls = {entry.url for entry in current}
        else:
            changed_urls = {entry.url for entry in current} - old_urls

    if not changed_urls:
        print("No source URLs changed since HEAD; nothing to do.")
        return 0

    updates: list[tuple[SourceEntry, str]] = []
    downloads = 0
    # TemporaryDirectory always cleans up, including on exceptions and
    # Ctrl+C -- no fragile shell traps needed.
    with tempfile.TemporaryDirectory(prefix="update-checksums-") as workdir_name:
        workdir = Path(workdir_name)
        for url in sorted(changed_urls):
            affected = [entry for entry in current if entry.url == url]
            declared = next(
                (entry.checksum for entry in affected if entry.checksum), None
            )
            if declared is None:
                print(
                    f"warning: no source-checksum found for {url} "
                    f"(part {affected[0].part_name}); skipping",
                    file=sys.stderr,
                )
                continue

            print(f"Downloading {url}")
            artifact = workdir / f"artifact-{downloads}"
            download(url, artifact)
            downloads += 1

            # Several parts may share one URL; hash per actually declared
            # algorithm (they should all agree, but do not assume it).
            digests: dict[str, str] = {}
            for entry in affected:
                if not entry.checksum:
                    continue
                entry_algorithm = checksum_algorithm(
                    entry.checksum, context=f"part {entry.part_name}"
                )
                if entry_algorithm not in digests:
                    digests[entry_algorithm] = compute_checksum(
                        entry_algorithm, artifact
                    )
                value = f"{entry_algorithm}/{digests[entry_algorithm]}"
                if entry.checksum != value:
                    updates.append((entry, value))
                    print(f"  part '{entry.part_name}': {value}")
            artifact.unlink()

    if not updates:
        if downloads:
            # Artifacts were fetched but every digest already matched.
            print("Checksums already up to date.")
        else:
            print("Nothing to update.")
        return 0

    new_lines = list(original_lines)
    for entry, value in updates:
        replace_checksum_value(new_lines, entry, snapcraft_yaml, value)

    write_back(snapcraft_yaml, "".join(new_lines))
    print(f"Updated {len(updates)} source-checksum entries in {snapcraft_yaml}.")
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, graceful_shutdown)
    signal.signal(signal.SIGHUP, graceful_shutdown)
    try:
        sys.exit(main())
    except KeyboardInterrupt as exc:
        print(f"Interrupted ({exc}); temporary files cleaned up.", file=sys.stderr)
        sys.exit(130)
    except ChecksumUpdateError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)

