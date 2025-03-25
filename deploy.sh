#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting deployment process..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required dependencies
echo "📦 Installing dependencies..."
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    libpq-dev \
    docker.io \
    docker-compose \
    dos2unix

# Start and enable Docker service
echo "🐳 Setting up Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
echo "👤 Adding user to docker group..."
sudo usermod -aG docker $USER

# Create application directory
echo "📁 Setting up application directory..."
APP_DIR="/opt/video-streaming"
sudo mkdir -p $APP_DIR
sudo chown -R $USER:$USER $APP_DIR

# Copy application files
echo "📋 Copying application files..."
cp -r ./* $APP_DIR/
cd $APP_DIR

# Fix line endings
echo "🔧 Fixing line endings..."
dos2unix configure.sh build.sh run.sh
chmod +x configure.sh build.sh run.sh

# Build and run with Docker
echo "🏗️ Building and running application..."
docker-compose up --build -d

# Create systemd service file
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/video-streaming.service << EOF
[Unit]
Description=Video Streaming Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/local/bin/docker-compose up
ExecStop=/usr/local/bin/docker-compose down
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
echo "🔄 Setting up systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable video-streaming
sudo systemctl start video-streaming

echo "✅ Deployment completed successfully!"
echo "📝 Application is running on http://localhost:8000"
echo "📝 You can check the status with: sudo systemctl status video-streaming"
echo "📝 View logs with: sudo journalctl -u video-streaming -f" 