FROM debian:trixie-20260918-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a

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
