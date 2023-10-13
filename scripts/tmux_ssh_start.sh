#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
case $1 in
    v) tmux split-window -v "$CURRENT_DIR/tmux_ssh_list.sh $1";;
    h) tmux split-window -h "$CURRENT_DIR/tmux_ssh_list.sh $1";;
    w) tmux new-window "$CURRENT_DIR/tmux_ssh_list.sh $1";;
esac
#tmux display-popup -E "$CURRENT_DIR/tmux_ssh_list.sh $1"
