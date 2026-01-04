# Online Status Backend - Docker Configuration
# =============================================
# Build: docker build -t onlinestatus-backend .
# Run:   docker run -p 8000:8000 -e API_TOKEN=your-secret-token onlinestatus-backend
#
# For HTTPS with SSL certificates:
# 1. Place cert.pem and privkey.pem in this directory
# 2. Build and run the container

FROM tiangolo/uvicorn-gunicorn:python3.11

# Set the working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt /app/requirements.txt

# Install dependencies
RUN pip install --no-cache-dir --trusted-host pypi.python.org -r requirements.txt

# Copy application code
COPY main.py /app/main.py

# Copy SSL certificates (optional - create empty files if not using HTTPS)
# These will be overwritten if actual certs are provided
COPY cert.pem* /app/
COPY privkey.pem* /app/

# Environment variables
# API_TOKEN should be set at runtime: docker run -e API_TOKEN=your-token
ENV API_TOKEN="dev-token-change-me"
ENV USE_MOCK_DATA="false"

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/healthz || exit 1

# Run with HTTPS if certificates exist, otherwise HTTP
CMD if [ -f /app/privkey.pem ] && [ -f /app/cert.pem ] && [ -s /app/privkey.pem ]; then \
        uvicorn main:app --host 0.0.0.0 --port 8000 --ssl-keyfile /app/privkey.pem --ssl-certfile /app/cert.pem; \
    else \
        uvicorn main:app --host 0.0.0.0 --port 8000; \
    fi

