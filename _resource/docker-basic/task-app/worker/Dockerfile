FROM python:3.12-slim

WORKDIR /app

# Install dependencies first (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY worker.py .

# Create non-root user
RUN useradd -m -u 1001 worker
USER worker

CMD ["python", "worker.py"]
