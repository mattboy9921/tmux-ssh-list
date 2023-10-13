#!/usr/bin/env bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOST="$1"
COMMAND="$2"

#check_host() {
    #if ping -c 1 -W 1 "$HOST" &>/dev/null; then
#	fi
#}

reconnect() {
    local RECON_EXIT=0
    while ! ping -c 1 -W 1 "$HOST" &> /dev/null; do
	dialog --nook --no-cancel \
            --pause "$HOST offline, trying again in 10 seconds...\nEsc to cancel." 8 50 10
	RECON_EXIT="$?"
    done

    case $RECON_EXIT in
	0) eval "$COMMAND ; $CURRENT_DIR/tmux_ssh_reconnect.sh $HOST \"$COMMAND\"";;
	*) main_menu;;
    esac
}

main_menu() {
    CHOICE=$(dialog --clear \
        --title "SSH Disconnected" \
	--ok-label "Exit" \
	--cancel-label "Main Menu" \
	--extra-button --extra-label "Reconnect" \
        --yesno "SSH connection to $HOST has disconnected." 0 0 2>&1 >/dev/tty)

    local EXIT="$?"
    clear
    case $EXIT in
	1) eval "$CURRENT_DIR/tmux_ssh_list.sh";;
	3) reconnect;;
	*) ;;
    esac
}

main_menu
