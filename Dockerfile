FROM python:3.10-slim
RUN apt-get update
RUN apt-get install -y curl python3-dev autoconf g++
RUN apt-get install -y libpq-dev

# Deps for building secp256k1-py
RUN apt-get install -y build-essential automake pkg-config libtool libffi-dev

# tailscaled + tailscale CLI (kernel TUN works on fly machines, proven by
# dawson-mcrelay). Suite detected from the base image so apt always finds
# a matching Tailscale repo (bookworm/trixie).
RUN suite="$(. /etc/os-release && echo "$VERSION_CODENAME")" \
    && curl -fsSL "https://pkgs.tailscale.com/stable/debian/$suite.noarmor.gpg" \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL "https://pkgs.tailscale.com/stable/debian/$suite.tailscale-keyring.list" \
      -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update && apt-get install -y tailscale

RUN curl -sSL https://install.python-poetry.org | python3 - --version 2.3.2
ENV PATH="/root/.local/bin:$PATH"
WORKDIR /app
COPY . .
RUN poetry config virtualenvs.create false
RUN poetry install --without dev --no-root

EXPOSE 3338

# poetry resolves the `mint` script from [tool.poetry.scripts] against the
# /app source tree even though the root package is not installed (--no-root)
ENTRYPOINT ["/app/docker/mint-entrypoint.sh"]
CMD ["poetry", "run", "mint"]
