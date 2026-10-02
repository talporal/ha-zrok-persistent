FROM debian:bookworm-slim

ARG ZROK_VERSION=1.1.12

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        curl \
        jq \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
    "https://github.com/openziti/zrok/releases/download/v${ZROK_VERSION}/zrok_${ZROK_VERSION}_linux_amd64.tar.gz" \
    -o /tmp/zrok.tar.gz \
    && mkdir -p /tmp/zrok-extract \
    && tar -xzf /tmp/zrok.tar.gz -C /tmp/zrok-extract \
    && install -m 0755 /tmp/zrok-extract/zrok /usr/local/bin/zrok \
    && zrok version \
    && rm -rf /tmp/zrok.tar.gz /tmp/zrok-extract

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
