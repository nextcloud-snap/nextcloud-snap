#!/usr/bin/env bash
#
# Refresh the `source-checksum` entries in snap/snapcraft.yaml.
#
# This runs automatically as a Renovate `postUpgradeTask` after Renovate bumps
# a `source:` URL, so that every version bump also carries a valid checksum.
# It can also be run by hand.
#
# Only sources whose URL differs from HEAD are downloaded and hashed, so a bump
# costs a single artifact download instead of re-hashing every component.
#
# Usage: .github/tools/update-checksums.sh [path/to/snapcraft.yaml]

set -euo pipefail

snapcraft_yaml="${1:-snap/snapcraft.yaml}"

if [ ! -f "$snapcraft_yaml" ]; then
        echo "error: $snapcraft_yaml does not exist" >&2
        exit 1
fi

# Print the URL of every `source:` line read from stdin.
source_urls() {
        grep -E '^[[:space:]]*source:[[:space:]]+https?://' \
                | sed -E 's/^[[:space:]]*source:[[:space:]]+//' \
                | sed -E 's/[[:space:]]+$//'
}

# Print the checksum algorithm (e.g. sha256) declared for the given source URL.
checksum_algorithm_for() {
        local url="$1"
        awk -v url="$url" '
                $1 == "source:" && $2 == url { found = 1; next }
                found && $1 == "source-checksum:" {
                        split($2, parts, "/")
                        print parts[1]
                        exit
                }
        ' "$snapcraft_yaml"
}

download() {
        local url="$1" output="$2"
        if command -v curl >/dev/null 2>&1; then
                # --max-time caps the whole transfer so a stalled download cannot
                # hang the run indefinitely; --retry/--connect-timeout handle
                # connection-level hiccups.
                curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 30 \
                        --max-time 1800 -o "$output" "$url"
        elif command -v wget >/dev/null 2>&1; then
                wget -q --tries=3 --timeout=30 -O "$output" "$url"
        else
                echo "error: neither curl nor wget is available" >&2
                return 1
        fi
}

compute_checksum() {
        local algorithm="$1" file="$2" tool
        case "$algorithm" in
                sha256) tool=sha256sum ;;
                sha512) tool=sha512sum ;;
                sha1)   tool=sha1sum ;;
                md5)    tool=md5sum ;;
                *)
                        echo "error: unsupported checksum algorithm '$algorithm'" >&2
                        return 1
                        ;;
        esac
        "$tool" "$file" | awk '{print $1}'
}

# Collect the URLs that changed relative to HEAD (Renovate applies its edits to
# the working tree before running these tasks, and commits afterwards).
old_list="$(mktemp)"
new_list="$(mktemp)"
map_file="$(mktemp)"
updated_yaml="$(mktemp)"
workdir="$(mktemp -d)"
cleanup() { rm -rf "$old_list" "$new_list" "$map_file" "$updated_yaml" "$workdir"; }
trap cleanup EXIT

# When the file cannot be read from HEAD (not a git repository, or the path is
# untracked/specified differently), every source is treated as changed and
# re-downloaded. That is safe but slow, so make the fallback visible.
if git show "HEAD:${snapcraft_yaml}" > /dev/null 2>&1; then
        git show "HEAD:${snapcraft_yaml}" | source_urls | sort -u > "$old_list" || true
else
        echo "warning: ${snapcraft_yaml} is not readable from HEAD; every remote source will be re-hashed" >&2
fi
source_urls < "$snapcraft_yaml" | sort -u > "$new_list"

changed="$(comm -13 "$old_list" "$new_list" || true)"

if [ -z "$changed" ]; then
        echo "No source URLs changed since HEAD; nothing to do."
        exit 0
fi

while IFS= read -r url; do
        [ -n "$url" ] || continue

        algorithm="$(checksum_algorithm_for "$url")"
        if [ -z "$algorithm" ]; then
                echo "warning: no source-checksum found for $url; skipping" >&2
                continue
        fi

        echo "Downloading $url"
        artifact="${workdir}/$(basename "${url%%\?*}")"
        download "$url" "$artifact"

        digest="$(compute_checksum "$algorithm" "$artifact")"
        printf '%s %s\n' "$url" "$digest" >> "$map_file"
done <<< "$changed"

if [ ! -s "$map_file" ]; then
        echo "Nothing to update."
        exit 0
fi

# Replace the source-checksum that follows each changed source line, keeping the
# declared algorithm and the original indentation.
awk -v map_file="$map_file" '
        BEGIN {
                while ((getline line < map_file) > 0) {
                        if (line == "") continue
                        split(line, parts, " ")
                        digest[parts[1]] = parts[2]
                }
        }
        {
                if ($1 == "source:" && ($2 in digest)) {
                        print
                        pending = $2
                        next
                }
                if (pending != "" && $1 == "source-checksum:") {
                        split($2, parts, "/")
                        sub(/source-checksum:.*/, "source-checksum: " parts[1] "/" digest[pending])
                        print
                        pending = ""
                        next
                }
                print
        }
' "$snapcraft_yaml" > "$updated_yaml"

if cmp -s "$snapcraft_yaml" "$updated_yaml"; then
        echo "Checksums already up to date."
else
        # Write in place to preserve the file's permissions.
        cat "$updated_yaml" > "$snapcraft_yaml"
        echo "Updated source-checksum entries in $snapcraft_yaml."
fi
