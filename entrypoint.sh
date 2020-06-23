#!/bin/bash

if [ -t 0 ]; then
    echo "~"
else
    echo "Having an interactive terminal is recommended, even if it is detached. Server console output may be broken."
fi

# vars

# for checkports
MCPORT=25565
AUTOSAVETIMEOUT=300
SYNCPRESENT="false"

# endvars

function exports {
    export PATH=$PATH:/userbin
}

function debugdata {
    whoami
    echo $HOME
    export
}

function checkenv {
    EXIT="false"
    if [[ -z "${REMOTE_RCLONE_AUTH}" ]]; then echo "Missing REMOTE_RCLONE_AUTH environment variable, this is obtained using 'rclone authorize \"<your remote type>\"'"; EXIT="true"; else echo "REMOTE_RCLONE_AUTH = ${REMOTE_RCLONE_AUTH}"; fi
    if [[ -z "${REMOTE_TYPE}" ]]; then echo "Missing REMOTE_TYPE environment variable, see rclone documentation for a list of supported storage system types https://rclone.org/overview/"; EXIT="true"; else echo "REMOTE_TYPE = ${REMOTE_TYPE}"; fi
    if [[ -z "${REMOTE_FOLDER}" ]]; then echo "Missing REMOTE_FOLDER environment variable, this should be the folder you store your server files in"; EXIT="true"; else echo "REMOTE_FOLER = ${REMOTE_FOLDER}"; fi
    
    # optionals
    if [[ -z "${STARTUP}" ]]; then echo "Missing optional environment variable (OPTIONAL)"; else echo "STARTUP = ${STARTUP}"; fi
    if [[ -z "${REMOTE_PORT}" ]]; then echo "Missing optional REMOTE_PORT environment variable (OPTIONAL)"; else echo "REMOTE_PORT = ${REMOTE_PORT}"; fi
    if [[ -z "${REMOTE_NGROK_TOKEN}" ]]; then echo "Missing optional REMOTE_NGROK_TOKEN environment variable (OPTIONAL)"; else echo "REMOTE_NGROK_TOKEN = ${REMOTE_NGROK_TOKEN}"; fi
    
    # verify
    if [[ "$EXIT" == "true" ]]; then
        echo "Please fix your environment variables and retry"
        exit
    else
        echo "$EXIT"
    fi
}

function checkports {
    # vars
    if [[ ! -z "${REMOTE_PORT}" ]]; then
        echo "Found alternative REMOTE_PORT"
        MCPORT="${REMOTE_PORT}"
    fi
    echo "Using server port $MCPORT"
}

function printngrok {
    if [[ ! -z "${REMOTE_NGROK_TOKEN}" ]]; then
        echo ""
        echo ""
        echo ""
        echo "*** *** *** *** *** *** *** *** *** *** *** *** *** *** ***"
        echo "PAY ATTENTION - NGROK CONNECTION DETAILS FOLLOW:"
        curl http://127.0.0.1:4040/api/tunnels | jq -r "."
        echo "*** *** *** *** *** *** *** *** *** *** *** *** *** *** ***"
        echo ""
        echo ""
        echo ""
    else
        echo "NGROK is not running"
    fi
}

function runoptionals {
    # heroku - binding too late problem (w/i 60 secs), so we make a web server
    if [[ ! -z "${PORT}" ]]; then
        echo "It appears a PORT environment variable was specified (likely heroku? We'll try to bind to it so we don't get killed (${PORT})"
        mkdir -p ~/shs-index
        cd ~/shs-index
        echo "Hey!" > index.html
        python -m SimpleHTTPServer ${PORT} &> /dev/null &
        SIMPLEHTTPSERVERPID=$!
        echo "SimpleHTTPServer Started"
        cd ~
    fi
    
    # ngrok - tcp tunneling mc server in casae a port can't be opened by docker host
    if [[ ! -z "${REMOTE_NGROK_TOKEN}" ]]; then
        echo "NGROK token found, starting ngrok..."
        eval "ngrok tcp -authtoken $REMOTE_NGROK_TOKEN -log=stdout ${REMOTE_NGROK_OPTS} ${MCPORT} > /dev/null &"
        NGROKPID=$!
        echo "NGROK started ($NGROKPID)"
        sleep 10
        until $(curl --output /dev/null --silent --head --fail http://127.0.0.1:4040/api/tunnels | jq -r ".tunnels[0]"); do
            printf '.'
            sleep 15
        done
        printngrok
    fi
    
    # custom save-all-task timeout
    if [[ ! -z "${AUTO_SAVE_TIMEOUT}" ]]; then
        echo "Custom auto-save timeout was found..."
        AUTOSAVETIMEOUT="$((${AUTO_SAVE_TIMEOUT} + 0))"
    fi
    echo "Auto save timeout: $AUTOSAVETIMEOUT"
}

function cleanupoptionals {
    if [[ ! -z "${REMOTE_NGROK_TOKEN}" ]]; then
        kill -9 $NGROKPID
        echo "NGROK closed"
    fi
    
    if [[ ! -z "${PORT}" ]]; then
        kill -9 $SIMPLEHTTPSERVERPID
        echo "SimpleHTTPServer closed"
    fi
    
    kill -9 $SVTASKSPID
}

function setuprclone {
    mkdir -p ~/.config/rclone
    rm -f ~/.config/rclone/rclone.conf
    echo "[main]" >> ~/.config/rclone/rclone.conf
    echo "type = ${REMOTE_TYPE}" >> ~/.config/rclone/rclone.conf
    echo "config_is_local = false" >> ~/.config/rclone/rclone.conf
    echo "token = ${REMOTE_RCLONE_AUTH}" >> ~/.config/rclone/rclone.conf
}

function syncdown {
    mkdir -p ~/server
    echo "Synchronizing from remote source ($REMOTE_TYPE)"
    rclone -v sync main:${REMOTE_FOLDER} ~/server
    echo "Synchronized, starting server..."
    SYNCPRESENT="true"
}

function syncup {
    if [[ "$SYNCPRESENT" == "true" ]]; then
        echo "Syncing changes to remote ($REMOTE_TYPE)"
        rclone -v sync ~/server main:${REMOTE_FOLDER}
        echo "Sync-up complete. It is safe to shut off server now."
    else
        echo "Will not sync-up, sync wasn't complete."
        echo "Will not sync-up, sync wasn't complete."
        echo "Will not sync-up, sync wasn't complete."
    fi
}

function startserver {
    cd ~/server
    STARTUPCOMMAND="java  -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -jar server.jar"
    if [[ ! -z "${STARTUP}" ]]; then
        echo "Found alternative startup command"
        STARTUPCOMMAND="${STARTUP}"
    fi
    echo "Startup -> ~ $STARTUPCOMMAND"
    if [ -t 0 ]; then
        #interactive
        eval "tmux new-session -d -s syncableproc '$STARTUPCOMMAND;touch /syncable-exited'"
    else
        eval "tmux new-session -d -s syncableproc '$STARTUPCOMMAND; echo syncable-exited >> ~/server/logs/latest.log;touch /syncable-exited'"
    fi
    echo "Sessions:"
    tmux list-sessions
    mv ~/server/logs/latest.log ~/server/logs/$(date +"%Y-%m-%d-%H-%M-%S").log
    #eval "$STARTUPCOMMAND"
    cd ~
}

function sendcommand {
    # -X stuff is ????
    eval "tmux send-keys '$1' C-m"
}

function attachserver {
    echo "Attaching to syncableproc"
    tmux attach-session -t syncableproc
}

function starttasks {
    # wait 60 seconds (hard coded) after startup before starting to auto-save so we can allow the server room to breath when starting up.
    sleep 60
    while true; do
        sleep $AUTOSAVETIMEOUT
        sendcommand "save-all"
        syncup
    done
}

function gracefulshutdown {
    echo "Caught exit signal, attempting to gracefully shutdown"
    echo "Asking server to save"
    sendcommand "save-all"
    echo "Asking server to stop"
    sendcommand "stop"
    echo "Synchronizing up (if possible)"
    syncup
    echo "Cleaning up extras"
    cleanupoptionals
    echo "Gracefully shutdown"
}

trap gracefulshutdown SIGINT
trap gracefulshutdown SIGTERM

# setup
cd ~
exports
debugdata
checkenv
checkports

# check optional features/things we need to do
runoptionals

# setup
setuprclone

# sync down
syncdown

# run, background for now
startserver
# save-all task for the all-important server files
starttasks &
SVTASKSPID=$!
printngrok
echo "Server is running"
if [ -t 0 ]; then
    # interactive
    echo "Interactive terminal detected, attaching to server"
    attachserver
else
    # non interactive
    echo "Noninteractive terminal detected waiting for exit of server"
    sleep 15
    while [ ! -f /syncable-exited ]; do
        echo "Trying to tail ~/server/logs/latest.log"
        tail -F -n 100 ~/server/logs/latest.log | grep -qx "syncable-exited"
        sleep 5
    done
    rm -f /syncable-exited
fi
# reattach

# shutdown
gracefulshutdown