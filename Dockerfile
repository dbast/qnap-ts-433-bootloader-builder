FROM debian:trixie-20260202-slim@sha256:f6e2cfac5cf956ea044b4bd75e6397b4372ad88fe00908045e9a0d21712ae3ba

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
