# Allow to build ontop of a base image
ARG BASE_IMAGE=ubuntu:23.10
FROM $BASE_IMAGE

ARG UID=1000
ARG GID=1000
ARG USERNAME=ubuntu

USER root

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # sudo for convenience
    sudo \
    # Required packages
    stow git ca-certificates curl zsh tmux \
    # devcontainer required
    ssh \
    # Other useful packages
    less htop  && \
    apt-get autoremove -y && \
    apt-get purge -y --auto-remove && \
    apt-get clean

# If the User does not exist, create it
# Otherwise, If the UID is not equal to the specified UID, run a usermod command to change
# the UID.
RUN if ! id -u ${USERNAME} > /dev/null 2>&1; then \
    groupadd -g ${GID} ${USERNAME} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/zsh ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd; \
    elif [ $(id -u ${USERNAME}) -ne ${UID} ]; then \
    usermod -u ${UID} ${USERNAME} && \
    echo "UID updated to ${UID}"; \
    else echo "User ${USERNAME} already has UID ${UID}"; \
    fi


ENV HOME /home/${USERNAME}
WORKDIR $HOME

USER ${USERNAME}

ENV TERM xterm-256color

# Copy the repo into the image
RUN mkdir dotfiles
COPY --chown=${USERNAME} . dotfiles/

# Run the setup script
RUN /bin/zsh $HOME/dotfiles/setup.sh

# This sources the zshrc file and then exits
RUN echo exit | script -qec zsh /dev/null

CMD ["/bin/zsh"]
