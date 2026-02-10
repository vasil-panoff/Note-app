#!/bin/bash
set -e
set -x

# === Update system and install dependencies ===
sudo yum update -y
sudo yum install -y python3 python3-pip unzip nginx

# === Environment variables ===
echo "AWS_REGION=eu-central-1" | sudo tee -a /etc/environment
echo "DYNAMO_TABLE_NAME=notes" | sudo tee -a /etc/environment
export AWS_REGION=eu-central-1
export DYNAMO_TABLE_NAME=notes

# --- Download Notes_App.zip from S3 ---
aws s3 cp s3://notes-app-s3-bucket-0001/Notes_App.zip /home/ec2-user/Notes_App/Notes_App.zip

# Ensure ec2-user owns the file
chown ec2-user:ec2-user /home/ec2-user/Notes_App/Notes_App.zip

# === Verify Notes_App.zip exists ===
if [ ! -f /home/ec2-user/Notes_App/Notes_App.zip ]; then
    echo "Error: Notes_App.zip not found in /home/ec2-user/Notes_App"
    exit 1
fi

# === Extract ZIP and set permissions ===
sudo unzip -o /home/ec2-user/Notes_App/Notes_App.zip -d /home/ec2-user/Notes_App
sudo chown -R ec2-user:ec2-user /home/ec2-user/Notes_App
sudo chmod +x /home/ec2-user/Notes_App/app.py

# === Install Python dependencies ===
sudo pip3 install -r /home/ec2-user/Notes_App/requirements.txt

# === Create systemd service for Flask app ===
sudo tee /etc/systemd/system/notes-app.service > /dev/null <<EOF
[Unit]
Description=Notes App Flask Service
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/Notes_App
ExecStart=/usr/bin/python3 /home/ec2-user/Notes_App/app.py
Restart=always
RestartSec=5
Environment="AWS_REGION=eu-central-1"
Environment="DYNAMO_TABLE_NAME=notes"

[Install]
WantedBy=multi-user.target
EOF

# === Enable and start Flask service ===
sudo systemctl daemon-reload
sudo systemctl enable notes-app
sudo systemctl start notes-app

# === Configure Nginx reverse proxy ===
sudo tee /etc/nginx/conf.d/notes-app.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# === Enable and start Nginx ===
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "Setup complete! Flask app should be running behind Nginx on port 80."
