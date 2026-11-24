FROM debian:trixie-20261123-slim@sha256:8aa5a7bf5a1955bddbe7d74fcdd0b91ab30e74362a8b73af672b0481b35b44a0

# Use Debian snapshot URLs for reproducible builds.
RUN sed -i 's|^# \(http://snapshot.debian.org/archive/[^ ]*\)$|URIs: \1|; s|^\(URIs: http://deb\.debian\.org/.*\)$|# \1|' \
        /etc/apt/sources.list.d/debian.sources \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
        # keep-sorted start
        bison \
        build-essential \
        flex \
        libgnutls28-dev \
        libssl-dev \
        python3 \
        python3-dev \
        python3-pyelftools \
        python3-setuptools \
        swig \
        # keep-sorted end
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
