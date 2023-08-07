# Allow to build ontop of a base image
ARG BASE_IMAGE=ubuntu:23.04
FROM $BASE_IMAGE

# TODO: UID/USER?
ARG UID=1000
ARG GID=1000

# If the UID is not 1000, run a usermod command to change the UID. Also, print
# a warning message.
RUN if [ ${UID} -ne 1000 ]; then \
    usermod -u ${UID} ubuntu && \
    echo "uid updated to ${UID}"; \
    fi
RUN if [ ${GID} -ne 1000 ]; then \
    groupmod -g ${GID} ubuntu && \
    echo "gid changed to ${GID}"; \
    fi

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends stow git ca-certificates curl zsh zsh-antigen && \
    apt-get autoremove -y && \
    apt-get purge -y --auto-remove && \
    apt-get clean

ENV HOME /home/ubuntu
WORKDIR $HOME

USER ubuntu

# Copy the repo into the image
RUN mkdir dotfiles
COPY --chown=ubuntu:ubuntu . dotfiles/

# Run the setup script
RUN /bin/zsh $HOME/dotfiles/setup.sh

RUN /bin/zsh $HOME/.zshrc

CMD ["/bin/zsh"]