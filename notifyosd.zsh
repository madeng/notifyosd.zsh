# commands to ignore
cmdignore=(htop tmux top vim vi fg)

# Function taken from undistract-me, get the current window id
function active_window_id () {
    if [[ -n $DISPLAY ]] ; then
        xprop -root _NET_ACTIVE_WINDOW | awk '{print $5}'
        return
    fi
    echo nowindowid
}

# end and compare timer, notify-send if needed
function notifyosd-precmd() {
    retval=$?
    if [[ ${cmdignore[(r)$cmd_basename]} == $cmd_basename ]]; then
        return
    else
        if [ ! -z "$cmd" ]; then
            cmd_end=$(date +%s)
            ((cmd_secs=$cmd_end - $cmd_start))
        fi

        if [ ! -z "$cmd" -a $cmd_secs -gt 10 ] && [[ "$cmd_active_win" != "$(active_window_id)" ]]; then
            if [ $retval -gt 0 ]; then
                cmdstat="with warning"
                urgency="critical"
            else
                cmdstat="successfully"
                urgency="normal"
            fi

            cmd_time="$cmd_secs seconds"

            if [ ! -z $SSH_TTY ] ; then
                notify-send -i utilities-terminal \
                        -u $urgency "$cmd_basename on $(hostname) completed $cmdstat" "\"$cmd\" took $cmd_time" 
            else
                notify-send -i utilities-terminal \
                        -u $urgency "$cmd_basename completed $cmdstat" "\"$cmd\" took $cmd_time" 
            fi
        fi
        unset cmd
    fi
}

# make sure this plays nicely with any existing precmd
precmd_functions+=( notifyosd-precmd )

# get command name and start the timer
function notifyosd-preexec() {
    cmd=$1
    cmd_basename=${${cmd:s/sudo //}[(ws: :)1]} 
    cmd_start=$(date +%s)
    cmd_active_win=$(active_window_id)
}

# make sure this plays nicely with any existing preexec
preexec_functions+=( notifyosd-preexec )
