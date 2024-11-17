# Use Python 3.12 slim image
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /app

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev gcc build-essential --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements.txt to the container
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code into the container
COPY . .

# Expose the port your Flask app runs on
EXPOSE 5000

# Run the Flask app
CMD ["flask", "run"]
