# TigerVNC Docker Image

This repository contains Docker images for TigerVNC with noVNC web interface.

## Features

- TigerVNC server for remote desktop access
- noVNC web interface for browser-based access
- Based on Ubuntu 22.04
- Includes automated testing scripts

## Quick Start

### Build the Docker image

```bash
docker-compose build
```

### Run the container

```bash
docker-compose up -d
```

### Connect to TigerVNC

- VNC client: `localhost:5901`
- Web browser: `http://localhost:6080/vnc.html`

## Testing

The repository includes several test scripts to verify functionality:

### Basic Connection Test

```bash
./tests/connection_test.sh
```

### Xvfb Connection Test

```bash
./tests/xvfb_connection_test.sh
```

### Performance Test

```bash
./tests/performance_test.sh
```

### Security Test

```bash
./tests/security_test.sh
```

## About TigerVNC

TigerVNC is a high-performance, platform-neutral implementation of VNC (Virtual Network Computing), a client/server application that allows users to launch and interact with graphical applications on remote machines.

Key features of TigerVNC include:
- High performance and security
- Platform-independent, with clients and servers for many platforms
- Maintained as an open-source project

## License

This project is licensed under the MIT License - see the LICENSE file for details. 