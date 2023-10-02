#!/usr/bin/env bash

# MattLabs SSH Menu - Finds all SSHable hosts in specified range and allows connecting to any of them
# SSH Key File Location
KEYFILE="~/keys/ml-internal-priv-openssh"
# Port to use for SSH
SSHPORT=22
# IP Range to Scan (separate by spaces)
# 10.0.1.225-244 are reserved for VIPs
IPRANGE="10.0.1.0-224 10.0.1.245-254 10.0.2-8.0-254"
# DNS Servers (Comma Separated)
DNSSERVERS=dns-03.mattlabs.net,dns-04.mattlabs.net
# Domain Name
DOMAINNAME=mattlabs.net
# Temp file location
TMPFILE="/tmp/sshHosts_$(date +%s)"
# Store menu options selected by the user
INPUT=/tmp/menu.sh.$$
# Get arg
ARG=$1
# Array for Dialog menu options
DIALOG_OPTIONS=()

# Function to run nmap and update the progress bar
run_nmap() {
    nmap $IPRANGE --stats-every 1s --open -Pn -R -T5 -p $SSHPORT --dns-servers $DNSSERVERS --max-rtt-timeout 10s -oG $TMPFILE 2>&1 \
    | {
        PERCENT=0
        ETA="..."
        while IFS= read -r line; do
            if [[ "$line" =~ "About" ]]; then
                progress=($(echo "$line" | awk 'gsub(/[.][0-9]+[%]/,"",$5) gsub(/[(]/,"",$9) { print $5,$9 }'))
                PERCENT="${progress[0]}"
                ETA="${progress[1]}"
                echo "XXX"
                echo "$PERCENT"
                echo "Estimated time remaining: $ETA"
                echo "XXX"
            fi
        done
    } | dialog --title "Scanning Hosts" --gauge "Initializing..." 6 50 0

    # Construct the OPTIONS array
    OPTIONS=()
    while read -r line; do
        tag=$(echo "$line" | awk '{print $1}')
        item=$(echo "$line" | awk '{print $2}')
        OPTIONS+=("$tag" "$item")
    done < <(cat "$TMPFILE" | grep "/open" | awk 'gsub(/\(\)/,"No-Hostname",$3) { print $3,$2 }; gsub(/[)(]|.'$DOMAINNAME'/,"",$3) { print $3,$2 }' | sort -k1)

    # Create a formatted array for dialog
    for ((i = 0; i < ${#OPTIONS[@]}; i+=2)); do
        DIALOG_OPTIONS+=("${OPTIONS[i]}" "${OPTIONS[i+1]}")
    done

    rm $TMPFILE
}

main_menu() {
    ### display main menu ###
    CHOICE=$(dialog --clear --backtitle "MattLabs SSH-01 Relay" \
        --title "[ M A I N - M E N U ]" \
        --extra-button --extra-label "Test" \
        --menu "Welcome, Matt. Please choose an SSH client \n \
        to connect to. You will return here after \n \
        logging out of your server of choice. \n \
        Choose your server:" 15 50 4 \
        "${DIALOG_OPTIONS[@]}" 2>&1 >/dev/tty)

    EXIT="$?"
    clear
    case $EXIT in
        0) ssh_to_server;;
        3) echo "Edit $CHOICE options";;
        *) echo "Cancelled!";;
    esac
}

# Connects us to the SSH server, creating a new tmux session based on existing sessions
ssh_to_server() {
    # Remote command to run in the SSH command below
    SSH_COMMAND="ssh $CHOICE"
    # Figure out the current number of sessions
    echo "Setting up SSH session..."
    NUM_SES=$(eval $SSH_COMMAND "-o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' tmux list-sessions 2>/dev/null | wc -l")
    REM_COMMAND="-t \"tmux new-session -A -s $NUM_SES\""
    # Connect based on arg for horiz/vert/win
    case $ARG in
	v) tmux split-window -v "eval $SSH_COMMAND $REM_COMMAND";;
	h) tmux split-window -h "eval $SSH_COMMAND $REM_COMMAND";;
	w) tmux new-window "eval $SSH_COMMAND $REM_COMMAND";;
    esac
}

# Run the nmap scan
run_nmap

# Start main menu
main_menu
