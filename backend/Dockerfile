# Use Python 3.14 as the base image
FROM python:3.14-slim

# Set the working directory inside the container
WORKDIR /app

# Copy requirements file (we'll create this next)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Expose the port the app runs on
EXPOSE 5000

# Command to run the application
CMD ["python", "app.py"]