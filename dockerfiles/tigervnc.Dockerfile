# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# TIGERVNC STAGE: Adds TigerVNC server on top of the base image
# -----------------------------------------------------------------------------
ARG BASE_IMAGE=tigervnc-base:latest
FROM ${BASE_IMAGE} AS vnc

# Set shell options for safety
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install TigerVNC from Ubuntu repositories (latest available version)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tigervnc-standalone-server=1.12.0+dfsg-4ubuntu0.22.04.1 \
    tigervnc-common=1.12.0+dfsg-4ubuntu0.22.04.1 \
    && TIGERVNC_VERSION=$(dpkg-query -W -f='${Version}' tigervnc-standalone-server) \
    && echo "export TIGERVNC_VERSION_INFO=${TIGERVNC_VERSION}" > /etc/tigervnc-version \
    && rm -rf /var/lib/apt/lists/*

# Add VNC-specific metadata
LABEL org.opencontainers.image.base.name="tigervnc-base" \
      org.opencontainers.image.title="tigervnc-devenv" \
      org.opencontainers.image.description="TigerVNC server environment" \
      org.opencontainers.image.source="https://github.com/drengskapur/tigervnc"

# Add version as a separate label
RUN . /etc/tigervnc-version && \
    echo "LABEL org.opencontainers.image.version=\"${TIGERVNC_VERSION_INFO}\"" >> /etc/docker-labels

# Set environment variable for the VNC version
RUN . /etc/tigervnc-version && \
    echo "ENV VNC_VERSION=${TIGERVNC_VERSION_INFO}" >> /etc/docker-labels

# Configure VNC using common config
RUN mkdir -p /etc/vnc/tigervnc && \
    cp /etc/vnc/common/config /etc/vnc/tigervnc/config

# Configure supervisord for TigerVNC
RUN echo "[program:vnc]" > /etc/supervisor/conf.d/vnc.conf && \
    echo "command=tigervncserver -xstartup /usr/bin/xterm -noreset -fg -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE :1" >> /etc/supervisor/conf.d/vnc.conf && \
    echo "autostart=true" >> /etc/supervisor/conf.d/vnc.conf && \
    echo "autorestart=true" >> /etc/supervisor/conf.d/vnc.conf && \
    echo "stdout_logfile=/var/log/supervisor/vnc.log" >> /etc/supervisor/conf.d/vnc.conf && \
    echo "stderr_logfile=/var/log/supervisor/vnc.err" >> /etc/supervisor/conf.d/vnc.conf

# -----------------------------------------------------------------------------
# NOVNC STAGE: Adds noVNC web client on top of VNC
# -----------------------------------------------------------------------------
FROM vnc AS novnc

# Import version info from previous stage
COPY --from=vnc /etc/tigervnc-version /etc/tigervnc-version
COPY --from=vnc /etc/docker-labels /etc/docker-labels

# Add noVNC-specific metadata
LABEL org.opencontainers.image.base.name="tigervnc-devenv" \
      org.opencontainers.image.title="tigervnc-novnc-devenv" \
      org.opencontainers.image.description="TigerVNC with noVNC web client" \
      org.opencontainers.image.source="https://github.com/drengskapur/tigervnc"

# Install and configure noVNC
WORKDIR /usr/local/share
RUN git clone https://github.com/novnc/noVNC.git novnc

# Add version info - moved after git clone
WORKDIR /usr/local/share/novnc
RUN . /etc/tigervnc-version && \
    NOVNC_VERSION=$(git describe --tags) && \
    echo "LABEL org.opencontainers.image.version=\"tigervnc-${TIGERVNC_VERSION_INFO}-novnc-${NOVNC_VERSION}\"" >> /etc/docker-labels

# Apply all labels
LABEL org.opencontainers.image.version="tigervnc-novnc"

# Add noVNC environment variables
ENV NOVNC_PORT=6080

# Configure noVNC
RUN NOVNC_VERSION=$(git describe --tags) && \
    git checkout "${NOVNC_VERSION}" && \
    cp vnc.html index.html && \
    echo "/* Use default styling */" > app/styles/custom.css

# Use the noVNC supervisor config template
RUN cp /etc/supervisor/conf.d/novnc.conf.template /etc/supervisor/conf.d/novnc.conf

# Reset working directory to root
WORKDIR /

# Expose noVNC port
EXPOSE 6080

# Update health check for noVNC
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:6080 || exit 1 