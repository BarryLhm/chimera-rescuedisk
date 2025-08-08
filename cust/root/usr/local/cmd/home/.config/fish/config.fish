if status is-interactive
    # Commands to run in interactive sessions can go here
    if [ "$TERM" = linux ]
        set -gx LANG C
    end
end
