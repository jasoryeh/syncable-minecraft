FROM alpine

ARG JDK=openjdk8

MAINTAINER Jason Ho <docker@hogt.me>

# dependencies
RUN apk add bash curl wget unzip jq python3 tmux openssh util-linux-misc $JDK
# for adding binaries
RUN mkdir -p /userbin && cd /userbin && chmod -R 777 /userbin
RUN curl https://rclone.org/install.sh | bash

ADD . .

# EXPOSE xxx
EXPOSE 25565

COPY ./entrypoint.sh /entrypoint.sh
CMD [ "/bin/bash", "/entrypoint.sh" ]
