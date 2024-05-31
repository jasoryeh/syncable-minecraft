FROM openjdk:8-jre-slim

MAINTAINER Jason Ho <jason@jasonho.tk>

# dependencies
RUN apt update && apt -y install curl wget unzip jq python tmux ssh
# for adding binaries
RUN mkdir -p /userbin && cd /userbin && chmod -R 777 /userbin
RUN curl https://rclone.org/install.sh | bash

ADD . .

# EXPOSE xxx
EXPOSE 25565

COPY ./entrypoint.sh /entrypoint.sh
CMD [ "/bin/bash", "/entrypoint.sh" ]
