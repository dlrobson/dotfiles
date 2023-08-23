# Allow to build ontop of a base image
ARG BASE_IMAGE=ubuntu:23.04
FROM $BASE_IMAGE

ARG UID=1000
ARG GID=1000
ARG USERNAME=ubuntu

USER root

# If the UID is not 1000, run a usermod command to change the UID. Also, print
# a warning message.
RUN if [ ${UID} -ne 1000 ]; then \
    usermod -u ${UID} ${USERNAME} && \
    echo "uid updated to ${UID}"; \
    fi

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Required packages
    stow git ca-certificates curl zsh tmux \
    # Other useful packages
    less htop && \
    apt-get autoremove -y && \
    apt-get purge -y --auto-remove && \
    apt-get clean

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
