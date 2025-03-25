#!/bin/sh
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "🚨 Must be run as root!"
    exit 1
fi

if [ "$(uname)" = "Darwin" ]; then
    echo "🚫 macOS is not supported!"
    exit 1
fi

if [ -f /.dockerenv ]; then
    echo "📦 Running inside a container is not supported!"
    exit 1
fi

for cmd in curl lsof awk docker; do
    if ! command -v $cmd >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq $cmd || yum install -y -q $cmd || echo "⚠️ Failed to install $cmd! Install manually." && exit 1
    fi
done

for port in 80 443 3000; do
    if lsof -i :$port -sTCP:LISTEN >/dev/null 2>&1; then
        echo "🔥 Port $port is already in use! Free it before proceeding."
        exit 1
    fi
done

if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 Docker not found, installing..."
    curl -fsSL https://get.docker.com | sh
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker installation failed! Install manually."
        exit 1
    fi
    echo "✅ Docker installed successfully!"
else
    echo "✔️ Docker is already installed and running."
fi

echo "🔄 Leaving Docker Swarm (if applicable)..."
docker swarm leave --force >/dev/null 2>&1 || true

echo "⬇️ Pulling EasyPanel image..."
docker pull easypanel/easypanel:latest

echo "🚀 Running EasyPanel setup..."
docker run --rm -i \
  -v /etc/easypanel:/etc/easypanel \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  easypanel/easypanel setup

USER_IP=$(hostname -I | awk '{print $1}')

echo "✅ EasyPanel setup completed!"
echo "⏳ It may take up to 60 seconds to be fully operational."
echo "🌐 Visit EasyPanel at: http://$USER_IP:3000/"
