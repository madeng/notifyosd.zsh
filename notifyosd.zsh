# To be sourced

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
    # Do not activate notifications from inside an SSH session. Though, it could
    # actually work using X if it is configured correctly.
    return
fi

# Default timeout is 10 seconds.
LONG_RUNNING_COMMAND_TIMEOUT=${LONG_RUNNING_COMMAND_TIMEOUT:-10}

# Set gt 0 to enable GNU units for time results. Disabled by default.
NOTIFYOSD_GNUUNITS=${NOTIFYOSD_GNUUNITS:-0}

# commands to ignore
cmdignore=(htop tmux top vim)

# Figure out the active Tmux window
function active_tmux_window() {
    [ -n "$TMUX" ] || {
        echo notmux
        return 1
    }
    tmux display-message -p '#W'
}

function active_tmux_session() {
    [ -n "$TMUX" ] || {
        echo notmux
        return 1
    }
    tmux display-message -p '#S'
}

# Function taken from undistract-me, get the current window id
function active_window_id() {
    if [[ -n $DISPLAY ]] ; then
        xprop -root _NET_ACTIVE_WINDOW | awk '{print $5}'
        return
    fi
    echo nowindowid
}

function is_window_unfocused() {
    [[ "$cmd_active_win" != $(active_window_id) ]] || [[ "$cmd_tmux_win" != $(active_tmux_window) ]]
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

        if [ ! -z "$cmd" -a $cmd_secs -gt ${LONG_RUNNING_COMMAND_TIMEOUT:-10} ] && is_window_unfocused; then
            if [ $retval -gt 0 ]; then
                cmdstat="with warning"
                sndstat="/usr/share/sounds/gnome/default/alerts/sonar.ogg"
                urgency="critical"
            else
                cmdstat="successfully"
                sndstat="/usr/share/sounds/gnome/default/alerts/glass.ogg"
                urgency="normal"
            fi

            if [ "$NOTIFYOSD_GNUUNITS" -gt 0 ]; then
                cmd_time=$(units "$cmd_secs seconds" "centuries;years;months;weeks;days;hours;minutes;seconds" | \
                        sed -e 's/\ +/\,/g' -e s'/\t//')
            else
                cmd_time="$cmd_secs seconds"
            fi

            tmux_info=''
            if active_tmux_window >/dev/null; then
                tmux_info="(tmux: $cmd_tmux_session/$cmd_tmux_win)"
            fi

            if [ ! -z $SSH_TTY ] ; then
                notify-send -i utilities-terminal \
                        -u $urgency "$cmd_basename on $(hostname) completed $cmdstat" "\"$cmd\" took $cmd_time $tmux_info"; \
                        play -q $sndstat
            else
                notify-send -i utilities-terminal \
                        -u $urgency "$cmd_basename completed $cmdstat" "\"$cmd\" took $cmd_time $tmux_info"; \
                        play -q $sndstat
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
    cmd_tmux_win=$(active_tmux_window)
    cmd_tmux_session=$(active_tmux_session)
}

# make sure this plays nicely with any existing preexec
preexec_functions+=( notifyosd-preexec )
