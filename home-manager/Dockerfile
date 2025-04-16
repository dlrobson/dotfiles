FROM ubuntu:24.04

# Install dependencies
RUN apt-get update 
RUN apt-get install -y sudo

# Create ubuntu user and configure sudo
RUN usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 440 /etc/sudoers.d/ubuntu

ENV USER=ubuntu

USER ubuntu

COPY . /home-manager

# Run the setup.sh script with sudo configuration
RUN /home-manager/setup.sh