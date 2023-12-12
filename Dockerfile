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
    # Required packages
    stow git ca-certificates curl zsh tmux \
    # devcontainer required
    ssh \
    # Other useful packages
    sudo less htop && \
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

# If the user is not a sudoer, add them to the sudo group
RUN cat /etc/sudoers.d/nopasswd | grep ${USERNAME} > /dev/null 2>&1 || \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Set the user's default shell
RUN chsh -s /bin/zsh ${USERNAME}

ENV HOME /home/${USERNAME}
WORKDIR $HOME

USER ${USERNAME}

# Copy the repo into the image
RUN mkdir dotfiles
COPY --chown=${USERNAME} . dotfiles/

# Run the setup script
RUN /bin/zsh $HOME/dotfiles/setup.sh

# This sources the zshrc file and then exits
RUN echo exit | script -qec zsh /dev/null

# Start a new tmux session in detached mode, source the tmux configuration
# file, and then kill the server. 
# `tmux new-session -d -s tmp` starts a new tmux session in detached mode
# (i.e., not visible to the user) with the name 'tmp'.
# `"tmux source-file ~/.tmux.conf; tmux kill-server"` is the command that is
# run in the new tmux session.
# `tmux source-file ~/.tmux.conf` sources (loads) the tmux configuration file.
# `tmux kill-server` then kills the tmux server, ending the session.
# This sequence is used to ensure that the tmux configuration file is correctly
# loaded in a tmux session environment.
RUN tmux new-session -d -s tmp "tmux source-file ~/.tmux.conf; tmux kill-server"

CMD ["/bin/zsh"]
