FROM debian:trixie-20260610-slim@sha256:eaa4b3f652544c3af35658e9315adab7858b51917b890d5f4b208e5575284e6d

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
