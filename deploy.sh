#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting deployment process..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Remove old Docker packages
echo "🧹 Removing old Docker packages..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo apt-get autoremove -y

# Install Docker prerequisites
echo "📦 Installing Docker prerequisites..."
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "🔑 Adding Docker's GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --batch --yes

# Set up the Docker repository
echo "📦 Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
echo "📦 Installing Docker..."
DEBIAN_FRONTEND=noninteractive sudo apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install required dependencies
echo "📦 Installing other dependencies..."
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    libpq-dev \
    dos2unix \
    nginx \
    certbot \
    python3-certbot-nginx

# Start and enable Docker service
echo "🐳 Setting up Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Configure Nginx
echo "🌐 Configuring Nginx..."
DOMAIN="video-streaming-api-v1.maibammaneesanasingh.studio"  # Your subdomain
sudo tee /etc/nginx/sites-available/video-streaming << EOF
server {
    listen 80;
    server_name $DOMAIN;  # Using the subdomain variable

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/video-streaming /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# Add current user to docker group
echo "👤 Adding user to docker group..."
sudo usermod -aG docker $USER

# Create application directory
echo "📁 Setting up application directory..."
APP_DIR="/opt/video-streaming-api-v1"
echo "Cleaning up existing directory if it exists..."
sudo rm -rf $APP_DIR
echo "Creating new application directory..."
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
# Use sudo for Docker commands
sudo docker compose up --build -d

# Create systemd service file
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/video-streaming-api-v1.service << EOF
[Unit]
Description=Video Streaming API v1 Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/sudo docker compose up
ExecStop=/usr/bin/sudo docker compose down
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
echo "🔄 Setting up systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable video-streaming-api-v1
sudo systemctl start video-streaming-api-v1

echo "✅ Deployment completed successfully!"
echo "📝 Application is running on http://localhost:8000"
echo "📝 You can check the status with: sudo systemctl status video-streaming-api-v1"
echo "📝 View logs with: sudo journalctl -u video-streaming-api-v1 -f" 