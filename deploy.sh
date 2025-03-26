#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting deployment process..."

# Install required dependencies
echo "📦 Installing dependencies..."
DEBIAN_FRONTEND=noninteractive sudo apt-get update && sudo apt-get install -y \
    libpq-dev \
    nginx \
    certbot \
    python3-certbot-nginx

# Configure Nginx
echo "🌐 Configuring Nginx..."
DOMAIN="video-streaming-api-v1.maibammaneesanasingh.studio"
sudo tee /etc/nginx/sites-available/video-streaming << EOF
server {
    listen 80;
    server_name $DOMAIN;

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

# Create application directory
echo "📁 Setting up application directory..."
APP_DIR="/opt/video-streaming-api-v1"
echo "Cleaning up existing directory if it exists..."
sudo rm -rf $APP_DIR
sudo mkdir -p $APP_DIR
sudo chown -R $USER:$USER $APP_DIR

# Copy application files
echo "📦 Copying application files..."
cp -r ~/app/build/* $APP_DIR/

# Set up systemd service
echo "⚙️ Setting up systemd service..."
sudo tee /etc/systemd/system/video-streaming.service << EOF
[Unit]
Description=Video Streaming Service
After=network.target postgresql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/video-streaming
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
echo "🚀 Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable video-streaming
sudo systemctl restart video-streaming

echo "✅ Deployment completed successfully!"
echo "📝 You can check the status with: sudo systemctl status video-streaming"
echo "📝 View logs with: sudo journalctl -u video-streaming -f" 