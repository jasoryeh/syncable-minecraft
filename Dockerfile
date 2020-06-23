FROM openjdk:8-jre-slim

MAINTAINER Jason Ho <jason@jasonho.tk>

# dependencies
RUN apt update && apt -y install curl wget unzip jq python tmux
RUN mkdir -p /userbin && cd /userbin && curl -o ngrok.zip https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip && unzip ngrok.zip && chmod -R 777 /userbin && chmod +x ngrok
RUN curl https://rclone.org/install.sh | bash

ADD . .

# EXPOSE xxx
EXPOSE 25565

COPY ./entrypoint.sh /entrypoint.sh
CMD [ "/bin/bash", "/entrypoint.sh" ]
