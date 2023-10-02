#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
tmux display-popup -E "$CURRENT_DIR/tmux_ssh_list.sh $1"
