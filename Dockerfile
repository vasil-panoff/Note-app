FROM python:3.11-slim

# Install Nginx
RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
 && pip install --no-cache-dir -r requirements.txt

# Copy your app (including sqlite DB if needed)
COPY . .

# Configure Nginx
RUN echo 'server { \
    listen 80; \
    location / { \
        proxy_pass http://127.0.0.1:8000; \
    } \
}' > /etc/nginx/sites-available/default

EXPOSE 80 8000

# Run Nginx + Gunicorn
CMD ["sh", "-c", "service nginx start && gunicorn -b 0.0.0.0:8000 app:app"]