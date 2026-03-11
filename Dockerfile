# Base image - Ubuntu LTS
FROM ubuntu:22.04

# Avoid interactive prompts during package install
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies: fortune, cowsay, netcat (for serving HTTP)
RUN apt-get update && apt-get install -y \
    fortune-mod \
    cowsay \
    netcat-openbsd \
    bash \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# cowsay installs to /usr/games, add it to PATH
ENV PATH=$PATH:/usr/games

# Set working directory
WORKDIR /app

# Copy the wisecow shell script into container
COPY wisecow.sh .

# Make it executable
RUN chmod +x wisecow.sh

# App runs on port 4499
EXPOSE 4499

# Start the wisecow application
CMD ["bash", "wisecow.sh"]
