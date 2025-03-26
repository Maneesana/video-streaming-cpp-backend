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
echo "Source directory contents:"
ls -la ~/app/build/
echo "Copying files to $APP_DIR..."
cp -v ~/app/build/video-streaming $APP_DIR/
cp -v ~/app/build/libvideo-streaming-lib.a $APP_DIR/

# Copy oatpp-swagger resources
echo "📦 Copying oatpp-swagger resources..."
mkdir -p $APP_DIR/external/oatpp-swagger/res
cp -r ~/app/build/external/oatpp-swagger/res/* $APP_DIR/external/oatpp-swagger/res/
echo "Oatpp-swagger resources copied:"
ls -la $APP_DIR/external/oatpp-swagger/res/

# Verify required files exist
echo "🔍 Verifying required files..."
if [ ! -f "$APP_DIR/video-streaming" ]; then
    echo "❌ Error: video-streaming executable not found"
    exit 1
fi

if [ ! -f "$APP_DIR/libvideo-streaming-lib.a" ]; then
    echo "❌ Error: libvideo-streaming-lib.a not found"
    exit 1
fi

if [ ! -d "$APP_DIR/external/oatpp-swagger/res" ]; then
    echo "❌ Error: oatpp-swagger resources directory not found"
    exit 1
fi

# Verify PostgreSQL connection
echo "🔍 Verifying PostgreSQL connection..."
if ! psql -h localhost -U postgres -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Error: Cannot connect to PostgreSQL"
    echo "Please check if PostgreSQL is running and credentials are correct"
    exit 1
fi

echo "✅ PostgreSQL connection verified"

# Set proper permissions
echo "🔒 Setting proper permissions..."
sudo chmod +x $APP_DIR/video-streaming
sudo chown -R $USER:$USER $APP_DIR
echo "Final permissions:"
ls -l $APP_DIR/video-streaming

# Set up systemd service
echo "⚙️ Setting up systemd service..."
sudo tee /etc/systemd/system/video-streaming.service << EOF
[Unit]
Description=Video Streaming Service
After=network.target postgresql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/video-streaming-api-v1
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=DB_USER=postgres
Environment=DB_PASSWORD=db-pass
Environment=DB_NAME=postgres
Environment=LD_LIBRARY_PATH=/lib/x86_64-linux-gnu
ExecStart=/bin/bash -c 'cd /opt/video-streaming-api-v1 && ./video-streaming'
StandardOutput=append:/var/log/video-streaming.log
StandardError=append:/var/log/video-streaming.error.log
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Create log files with proper permissions
echo "📝 Setting up log files..."
sudo touch /var/log/video-streaming.log /var/log/video-streaming.error.log
sudo chown $USER:$USER /var/log/video-streaming.log /var/log/video-streaming.error.log
sudo chmod 644 /var/log/video-streaming.log /var/log/video-streaming.error.log

# Reload systemd and start service
echo "🚀 Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable video-streaming
sudo systemctl restart video-streaming

# Verify service is running
echo "🔍 Verifying service status..."
if ! sudo systemctl is-active --quiet video-streaming; then
    echo "❌ Error: Service failed to start"
    echo "Checking logs..."
    sudo journalctl -u video-streaming -n 50
    sudo cat /var/log/video-streaming.error.log
    exit 1
fi

echo "✅ Service is running"

# Wait for application to be ready
echo "⏳ Waiting for application to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8000/ > /dev/null; then
        echo "✅ Application is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Error: Application failed to start"
        echo "Checking logs..."
        sudo journalctl -u video-streaming -n 50
        sudo cat /var/log/video-streaming.error.log
        exit 1
    fi
    echo "Waiting... ($i/30)"
    sleep 1
done

echo "✅ Deployment completed successfully!"
echo "📝 You can check the status with: sudo systemctl status video-streaming"
echo "📝 View logs with: sudo journalctl -u video-streaming -f" 