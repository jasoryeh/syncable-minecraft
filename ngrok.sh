#!/bin/bash

source ./logger.sh
source ./ngrokinfo.sh

function start_ngrok {
    log_info "Starting ngrok: ($1) with auth:($2)"
    eval "ngrok tcp -authtoken $2 -log=stdout $1" &
    NGROKPID=$!
    log_info "ngrok process started with PID ($NGROKPID)"
    until $(curl --output /dev/null --silent --head --fail http://127.0.0.1:4040/api/tunnels | jq -r ".tunnels[0]"); do
        printf '... '
        sleep 1
    done
    spacer "\n\n\n" "\n"
    log_info "ngrok process active, use '_syncable ngrok' to show tunnel details"
    sleep 15 && bash /ngrokinfo.sh
    spacer "\n" "\n\n\n\n"
}

if [[ ! -z $NGROK_AUTH ]]; then
    if [[ -z $NGROK_PORT ]]; then
        log_warning "Using default port 25565 as no ngrok port was passed to us."
        NGROK_PORT="25565"
    fi
    start_ngrok "$NGROK_PORT" "$NGROK_AUTH"
else
    log_info "ngrok not starting, authorization token not specified!"
fi