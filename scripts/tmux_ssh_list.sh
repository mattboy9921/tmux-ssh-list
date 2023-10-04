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
# Options
CONFIG_DIR="$HOME/.config/tmux-ssh-list"
declare -A FIELDS_MAP

# Setup function
setup() {
    mkdir -p "$CONFIG_DIR"
}

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
    # Title based on arg
    case $ARG in
	v) TITLE="SSH - Split Vertical";;
	h) TITLE="SSH - Split Horizontal";;
	w) TITLE="SSH - New Window";;
    esac
    ### display main menu ###
    CHOICE=$(dialog --clear --backtitle "MattLabs SSH-01 Relay" \
        --title "$TITLE" \
	--ok-label "Connect" \
        --extra-button --extra-label "Edit" \
        --menu "All SSH hosts have been found. Please make a selection below." 15 50 4 \
        "${DIALOG_OPTIONS[@]}" 2>&1 >/dev/tty)

    local EXIT="$?"
    # Update field map
    FIELDS_MAP["Username"]="$(ssh -G $CHOICE | grep '^user ' | cut -d ' ' -f 2)"
    FIELDS_MAP["Tmux"]="1"
    clear
    case $EXIT in
        0) ssh_to_server;;
        3) edit_menu "$CHOICE";;
        *) ;;
    esac
}

# Connects us to the SSH server, creating a new tmux session based on existing sessions
ssh_to_server() {
    # Get options
    local USER_VAL=$(read_value $CHOICE "Username")
    local TMUX_VAL=$(read_value $CHOICE "Tmux")

    # Remote command to run in the SSH command below
    SSH_COMMAND="ssh $USER_VAL@$CHOICE"

    dialog --infobox "Setting up SSH command to $CHOICE..." 5 40

    if [ "$TMUX_VAL" -eq 1 ]; then
    # Figure out the current number of sessions
    NUM_SES=$(eval $SSH_COMMAND "-o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' tmux list-sessions 2>/dev/null | wc -l")
    REM_COMMAND="-t 'tmux new-session -A -s $NUM_SES'"
    SSH_COMMAND="$SSH_COMMAND $REM_COMMAND"
    fi

    dialog --infobox "Connecting to $CHOICE via command:\n$SSH_COMMAND" 5 40
    #dialog --infobox "Username is $USER and TMUX is $TMUX" 5 40

    # Connect based on arg for horiz/vert/win
    case $ARG in
	v) tmux split-window -v "eval $SSH_COMMAND";;
	h) tmux split-window -h "eval $SSH_COMMAND";;
	w) tmux new-window "eval $SSH_COMMAND";;
    esac
}

edit_menu() {
    local HOST="$1"

    # Make file for host
    touch "$CONFIG_DIR"/"$HOST"

    local EDIT_OPTIONS=()
    for key in "${!FIELDS_MAP[@]}"; do
	EDIT_OPTIONS+=("$key" "$(read_value $HOST $key)")
    done

    local EDIT_CHOICE
    EDIT_CHOICE=$(dialog --ok-label "Edit" \
	--cancel-label "Back" \
	--extra-button --extra-label "Default" \
	--menu "SSH connection options for $HOST." 15 50 4 \
	"${EDIT_OPTIONS[@]}" 2>&1 >/dev/tty)

    local EXIT="$?"
    case $EXIT in
	    0) write_text_value "$HOST" "$EDIT_CHOICE" "$(read_value $HOST $EDIT_CHOICE)"; edit_menu "$HOST";;
	3) remove_text_value "$HOST" "$EDIT_CHOICE"; edit_menu "$HOST";;
	*) main_menu;;
    esac
}

read_value() {
    local HOST="$1"
    local KEY="$2"

    # Get value from file
    VALUE=$(grep -s -o "$KEY=[^[:space:]]*" "$CONFIG_DIR"/"$HOST" | cut -d '=' -f 2)
    if [ -z "$VALUE" ]; then
        VALUE="${FIELDS_MAP[$KEY]}"
    fi
    echo "$VALUE"
}

write_text_value() {
    local HOST="$1"
    local FIELD="$2"
    local CURRENT_VAL="$3"
    local FILE="$CONFIG_DIR/$HOST"

    # Display text input box
    local NEW_VAL
    NEW_VAL=$(dialog --ok-label "Save" \
	--inputbox "Edit $FIELD for $HOST." 15 40 "$CURRENT_VAL" 2>&1 >/dev/tty)

    local EXIT="$?"
    case $EXIT in
	0)
            if grep -q "$FIELD=$CURRENT_VAL" "$FILE"; then
	        sed -i "s/^$FIELD=$CURRENT_VAL$/$FIELD=$NEW_VAL/" $FILE
            else
                echo "$FIELD=$NEW_VAL" >> $FILE
            fi

	    # Show message
	    dialog --infobox "$FIELD for $HOST has been set to: $NEW_VAL" 5 40
	    sleep 2
	    ;;
    esac
}

remove_text_value() {
    local HOST="$1"
    local FIELD="$2"
    local FILE="$CONFIG_DIR/$HOST"

    sed -i "/^$FIELD/d" "$FILE"

    # Show message
    dialog --infobox "$FIELD for $HOST has been set to default." 5 40
    sleep 2
}

setup

# Run the nmap scan
run_nmap

# Start main menu
main_menu
