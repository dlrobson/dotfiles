# Allow to build ontop of a base image
ARG BASE_IMAGE=ubuntu:24.04
FROM $BASE_IMAGE

# Write the current username to a file
ENV WHOAMI_FILE=/tmp/whoami
RUN whoami > ${WHOAMI_FILE}
# The username to use in the container
ENV USERNAME=user
# The final home directory of the user
ENV HOME=/home/${USERNAME}

USER root

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # devcontainer required
    ssh \
    # For package installations
    sudo \
    # Other useful tools
    less htop && \
    rm -rf /var/lib/apt/lists/*

RUN export ORIGINAL_USERNAME=$(cat ${WHOAMI_FILE}) && \
    # If it's root, create a non-root user
    if [ "${ORIGINAL_USERNAME}" = "root" ]; then \
    useradd -m -s /bin/zsh ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd; \
    elif [ "${ORIGINAL_USERNAME}" != "${USERNAME}" ]; then \
    usermod --login ${USERNAME} ${ORIGINAL_USERNAME} --home /home/${USERNAME} --move-home; \
    # If the user is a sudoer, add them to the sudo group
    cat /etc/sudoers.d/nopasswd | grep ${USERNAME} > /dev/null 2>&1 || \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd; \
    fi && \
    rm ${WHOAMI_FILE} && \
    # Set the user's default shell
    chsh -s /bin/zsh ${USERNAME}

WORKDIR $HOME

# Copy the repo into the image
RUN mkdir dotfiles
COPY --chown=${USERNAME} . dotfiles/

# Install dependencies for the setup script
RUN /bin/sh -c "$HOME/dotfiles/setup.sh --install-dependencies" && \
    rm -rf /var/lib/apt/lists/*

USER user

# Run the setup script only setting up the dotfiles
RUN /bin/zsh -c "$HOME/dotfiles/setup.sh --dotfile-setup-only"

CMD ["/bin/zsh"]
