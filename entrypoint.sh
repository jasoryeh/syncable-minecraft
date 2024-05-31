#!/bin/bash

source ./logger.sh

spacer "\n" "\n" "syncable-minecraft"
log_info "Running as user: $(whoami)"
log_info "On platform: $(uname -a)"
log_info "CPU Information (lscpu):"
lscpu
log_info "Exports/Environment Variables:"
export
spacer "" "\n\n"

# make sure rclone and other manually installed binaries can be called from here
export PATH=$PATH:/userbin && chmod +x /userbin

function checkenv {
    spacer "" "\n" 
    log_info "Configuring environment..."

    EXIT="false"
    if [[ -z "${STORAGE_AUTH}" ]]; then
        log_error "Missing STORAGE_AUTH environment variable, this is obtained using 'rclone authorize \"<your remote type>\"'"
        EXIT="true"
    else
        log_info "    STORAGE_AUTH = ${STORAGE_AUTH}"
    fi
    
    if [[ -z "${STORAGE_TYPE}" ]]; then
        log_error "Missing STORAGE_TYPE environment variable, see rclone documentation for a list of supported storage system types https://rclone.org/overview/"
        EXIT="true"
    else
        log_info "    STORAGE_TYPE = ${STORAGE_TYPE}"
    fi
    
    # optionals
    if [[ -z "${STORAGE_FOLDER}" ]]; then
        log_warning "(OPTIONAL) STORAGE_FOLDER environment variable is missing! Default to /syncmc"
        STORAGE_FOLDER="/syncmc"
    fi
    log_info "    STORAGE_FOLDER = ${STORAGE_FOLDER}"
    
    if [[ -z "${STARTUP}" ]]; then
        log_warning "(OPTIONAL) STARTUP environment variable is missing!"
        STARTUP="java -jar server.jar"
    fi
    log_info "    STARTUP = ${STARTUP}"

    if [[ -z "${AUTOSAVE}" ]]; then
        log_warning "(OPTIONAL) AUTOSAVE environment variable is missing! Using default 300 seconds!"
        AUTOSAVE="300"
    fi
    log_info "    AUTOSAVE = ${AUTOSAVE}"

    # verify
    printf "\n\n"
    if [[ "$EXIT" == "true" ]]; then
        log_error "Please fix your environment variables and retry"
        exit
    else
        log_info "Information found, getting ready..."
    fi
    spacer "" "\n\n"
}

function setuprclone {
    spacer "" "\n"
    log_info "Configuring RCLONE..."

    mkdir -p ~/.config/rclone
    echo "[main]" > ~/.config/rclone/rclone.conf
    echo "type = ${STORAGE_TYPE}" >> ~/.config/rclone/rclone.conf
    echo "config_is_local = false" >> ~/.config/rclone/rclone.conf
    echo "token = ${STORAGE_AUTH}" >> ~/.config/rclone/rclone.conf

    log_info "RCLONE Configuration created."
    spacer "" "\n\n"
}

function syncdown {
    spacer "" "\n"
    log_info "Synchronizing from remote source ($STORAGE_TYPE) -> ($STORAGE_FOLDER)"
    rm -rf ~/server && mkdir -p ~/server && rclone -v sync main:$STORAGE_FOLDER ~/server && SYNCPRESENT="true"
    if [[ "$SYNCPRESENT" == "true" ]]; then
        log_info "Synchronized, starting server..."
    else
        log_error "Could not synchronize with storage provider! Exiting."
        log_error "Could not synchronize with storage provider! Exiting."
        log_error "Could not synchronize with storage provider! Exiting."
        exit
    fi
    spacer "" "\n\n"
}

function syncup {
    printf "\n"
    if [[ "$SYNCPRESENT" == "true" ]]; then
        log_info "Syncing changes to remote ($STORAGE_TYPE) -> ($STORAGE_FOLDER)"
        SYNCUPDONE="false" && rclone -v sync ~/server main:${STORAGE_FOLDER} && SYNCUPDONE="true"

        if [[ "$SYNCUPDONE" == "true" ]]; then
            log_info "Synchronized."
        else
            log_warning "Could not synchronize with storage provider!"
        fi
    else
        log_warning "Not syncronizing, the original sync did not compelete!"
        log_warning "Not syncronizing, the original sync did not compelete!"
        log_warning "Not syncronizing, the original sync did not compelete!"
    fi
    printf "\n"
}

function lock {
    cd ~/server
    printf "syncable-minecraft\n" > SYNCABLE_LOCK
    printf "$HOSTNAME\n" >> SYNCABLE_LOCK
    printf "$(curl https://checkip.amazonaws.com) $(date)\n" >> SYNCABLE_LOCK
    printf "$(cat server.properties | grep server-port)" >> SYNCABLE_LOCK
    if [[ -z $1 ]]; then
        syncup
    fi
    cd -
}

function unlock {
    cd ~/server
    rm -f SYNCABLE_LOCK
    if [[ -z $1 ]]; then
        syncup
    fi
    cd -
}

function startserver {
    spacer "" "\n"
    cd ~/server

    # check if this server is locked by another instance
    if [[ -f SYNCABLE_LOCK ]]; then
        log_error "Found SYNCABLE_LOCK lock file!"
        if [[ ! -z $LOCK_OVERRIDE ]]; then
            log_warning "  Overriding the lock file."
            unlock
        else
            log_error "  This server is currently locked"
            log_error "  by another instance of this "
            log_error "  container! Use LOCK_OVERRIDE "
            log_error "  if you are absolutely sure "
            log_error "  that there is no other server "
            log_error "  running. "
            exit
        fi
    fi

    log_info "Starting server [$STARTUP]"
    lock

    (while true; do sleep 1; done) | bash -c "$STARTUP" &
    SERVER_PID=$!
    
    log_info "Server started with PID of ($SERVER_PID)"
    sleep 3
    if [[ ! -d /proc/$SERVER_PID ]]; then
        log_error ""
        log_error "*** *** *** *** *** *** *** *** *** ***"
        log_error "  It looks like the server process "
        log_error "  ended early!"
        log_error ""
        log_error "  Ensure the files on the storage "
        log_error "  provider are correct, and try again."
        log_error ""
        log_error "  Result of ls:"
        ls
        log_error ""
        log_error "  Exiting so nothing bad happens."
        log_error "*** *** *** *** *** *** *** *** *** ***"
        unlock
        gracefulshutdown
    fi
    cd -
    spacer "" "\n\n"
}

function sendcommand {
    if [[ ! -z $SERVER_PID ]]; then
        log_info "Executing $* on process id $SERVER_PID"
        if [[ -d /proc/$SERVER_PID ]]; then
            printf "$*\n" >> /proc/$SERVER_PID/fd/0
        else
            log_error "Could not run command, no server!"
        fi
    fi
}

function killtasks {
    log_info "Stopping tasks..."
    kill -9 $TASKPIDS > /dev/null
    log_info "Tasks stopped."
}

function task_SAVE {
    sleep 60
    log_info "Starting save task"
    while true; do
        log_info "Auto-saving..."
        sendcommand "save-all"
        sleep $AUTOSAVE  # waits the auto save time before synchronizing, and then saves again
        log_info "Auto-save sync..."
        syncup
    done
}

function task_WATCH {
    while true; do
        if [[ ! -d /proc/$SERVER_PID ]]; then
            log_info "Server detected as turned off!"
            log_info "Server detected as turned off!"
            log_info "Server detected as turned off!"
            exit
        fi
    done
}

function starttasks {
    task_SAVE &
    TASKPIDS="${TASKPIDS} $!"
    task_WATCH &
    TASKPIDS="${TASKPIDS} $!"
}

function gracefulshutdown {
    log_info "Attempting graceful shutdown"
    sendcommand "stop"

    log_info "Waiting for server to stop"
    waitForServer "... "
    unlock "nosync"
    killtasks
    syncup

    log_info "Goodbye."
    exit
}

function waitForServer {
    until [[ ! -d /proc/$SERVER_PID ]]; do
        if [[ ! -z $* ]]; then
            printf "$*"
        fi
        sleep 1
    done
}

function optionalFeatures {
    # these features run on their own, and wont be given notification of any events
    cd /
    #bash sometask.sh &
    #TASKPIDS="${TASKPIDS} $!"
    if [[ ! -z $SIMULTANEOUS_CMD ]]; then
        echo "Running $SIMULTANEOUS_CMD"
        eval $SIMULTANEOUS_CMD &
        TASKPIDS="${TASKPIDS} $!"
    fi
    cd -
}

# catch signals
function catchsignal {
    function onTerminate {
        log_info "Caught exit signal, attempting to gracefully shutdown\n"
        gracefulshutdown
    }
    trap onTerminate SIGINT
    trap onTerminate SIGTERM
}
catchsignal

# setup
cd ~
checkenv
setuprclone
syncdown

startserver
starttasks
optionalFeatures

# wait for server, send commands while next
until [[ ! -d /proc/$SERVER_PID ]]; do
    # a limitation for now... in order for other things to work
    read -t 3 tempcmd
    if [[ ! -z $tempcmd ]]; then
        if [[ "$tempcmd" == "_syncable syncup" ]]; then
            syncup
        else
            sendcommand "$tempcmd"
        fi
    fi
    #sleep 1
done

gracefulshutdown
