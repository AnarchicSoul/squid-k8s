FROM ubuntu:22.04

LABEL maintainer="johan91"
LABEL description="Squid proxy server container for Kubernetes deployments"

# Install squid and utilities
RUN apt-get update && \
    apt-get install -y squid && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories and set permissions
RUN mkdir -p /var/spool/squid && \
    mkdir -p /var/log/squid && \
    mkdir -p /var/run/squid && \
    mkdir -p /run/squid && \
    chown -R proxy:proxy /var/spool/squid /var/log/squid /var/run/squid /run/squid

# Expose Squid default port
EXPOSE 3128

# Copy default configuration (can be overridden via ConfigMap in Kubernetes)
COPY squid.conf /etc/squid/squid.conf

# Initialize cache directories
RUN squid -z -N

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD squidclient -h localhost -p 3128 http://localhost/ || exit 1

# Run squid in foreground mode (required for Docker/Kubernetes)
CMD ["squid", "-N"]
