FROM ubuntu:bionic as builder

# Grab dependencies
RUN apt update
RUN apt dist-upgrade --yes
RUN apt install --yes curl sudo jq squashfs-tools

# Grab the core snap from the stable channel and unpack it in the proper place
RUN curl -L $(curl -H 'X-Ubuntu-Series: 16' 'https://api.snapcraft.io/api/v1/snaps/details/core' | jq '.download_url' -r) --output core.snap
RUN mkdir -p /snap/core
RUN unsquashfs -d /snap/core/current core.snap

# Grab the core18 snap from the stable channel and unpack it in the proper place
RUN curl -L $(curl -H 'X-Ubuntu-Series: 16' 'https://api.snapcraft.io/api/v1/snaps/details/core18' | jq '.download_url' -r) --output core18.snap
RUN mkdir -p /snap/core18
RUN unsquashfs -d /snap/core18/current core18.snap

# Grab the snapcraft snap from the stable channel and unpack it in the proper place
RUN curl -L $(curl -H 'X-Ubuntu-Series: 16' 'https://api.snapcraft.io/api/v1/snaps/details/snapcraft?channel=stable' | jq '.download_url' -r) --output snapcraft.snap
RUN mkdir -p /snap/snapcraft
RUN unsquashfs -d /snap/snapcraft/current snapcraft.snap

# Grab the go snap from the stable channel and unpack it in the proper place
RUN curl -L $(curl -H 'X-Ubuntu-Series: 16' 'https://api.snapcraft.io/api/v1/snaps/details/go?channel=stable' | jq '.download_url' -r) --output go.snap
RUN mkdir -p /snap/go
RUN unsquashfs -d /snap/go/current go.snap

# Create a snapcraft runner
RUN mkdir -p /snap/bin
RUN echo "#!/bin/sh" > /snap/bin/snapcraft
RUN snap_version="$(awk '/^version:/{print $2}' /snap/snapcraft/current/meta/snap.yaml)" && echo "export SNAP_VERSION=\"$snap_version\"" >> /snap/bin/snapcraft
RUN echo 'exec "$SNAP/usr/bin/python3" "$SNAP/bin/snapcraft" "$@"' >> /snap/bin/snapcraft
RUN chmod +x /snap/bin/snapcraft

# Create a go runner
RUN echo "#!/bin/sh" > /snap/bin/go
RUN snap_version="$(awk '/^version:/{print $2}' /snap/go/current/meta/snap.yaml)" && echo "export SNAP_VERSION=\"$snap_version\"" >> /snap/bin/go
RUN echo "export SNAP=\"/snap/go/current\"" >> /snap/bin/go
RUN echo "export SNAP_NAME=\"go\"" >> /snap/bin/go
RUN echo 'exec "$SNAP/command-go.wrapper" "$@"' >> /snap/bin/go
RUN chmod +x /snap/bin/go

# Create a gofmt runner
RUN echo "#!/bin/sh" > /snap/bin/gofmt
RUN snap_version="$(awk '/^version:/{print $2}' /snap/go/current/meta/snap.yaml)" && echo "export SNAP_VERSION=\"$snap_version\"" >> /snap/bin/gofmt
RUN echo "export SNAP=\"/snap/go/current\"" >> /snap/bin/gofmt
RUN echo "export SNAP_NAME=\"go\"" >> /snap/bin/gofmt
RUN echo 'exec "$SNAP/command-gofmt.wrapper" "$@"' >> /snap/bin/gofmt
RUN chmod +x /snap/bin/gofmt

# Multi-stage build, only need the snaps from the builder. Copy them one at a
# time so they can be cached.
FROM ubuntu:bionic
COPY --from=builder /snap/core /snap/core
COPY --from=builder /snap/core18 /snap/core18
COPY --from=builder /snap/snapcraft /snap/snapcraft
COPY --from=builder /snap/go /snap/go
COPY --from=builder /snap/bin/snapcraft /snap/bin/snapcraft
COPY --from=builder /snap/bin/go /snap/bin/go
COPY --from=builder /snap/bin/gofmt /snap/bin/gofmt

# Install snapd
RUN apt update && apt dist-upgrade --yes && apt install --yes snapd

# Generate locale
RUN apt install --yes sudo locales && locale-gen en_US.UTF-8

# Set the proper environment
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV PATH="/snap/bin:$PATH"
ENV SNAP="/snap/snapcraft/current"
ENV SNAP_NAME="snapcraft"
ENV SNAP_ARCH="amd64"
