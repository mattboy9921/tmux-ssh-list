#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
tmux bind % run-shell "$CURRENT_DIR/scripts/tmux_ssh_start.sh v"
tmux bind '"' run-shell "$CURRENT_DIR/scripts/tmux_ssh_start.sh h"
tmux bind c run-shell "$CURRENT_DIR/scripts/tmux_ssh_start.sh w"
