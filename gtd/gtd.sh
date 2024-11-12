#!/bin/bash

usage() {
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "inbox review and process inbox"
    echo "weekly    perform weekly review"
}

usage_daily() {
    echo
    echo "[e] Edit description"
    echo "[c] Complete"
    echo
    echo "Actionable Lists"
    echo "[n] Next Action"
    echo "[s] Schedule"
    echo "[p] Projects"
    echo
    echo "Non-Actionable Lists"
    echo "[b] Blocked (delegate)"
    echo "[z] Snooze"
    echo "[m] Maybe/Someday"
    echo "[d] Delete"
    echo
    echo "[Enter] Continue"
    echo "[?] Usage"
}


process_inbox() {
    # Process Inbox
    usage_daily
    task rc.defaultwidth=0 in | tail -n +4 | head -n -2 | while read line; do
        IFS=' ' read -r id desc <<< $line
        while true; do
            task ls ${id}
            echo $desc
            read -n 1 -p "Selection: " SELECTION < /dev/tty
            echo

            case "$SELECTION" in
                "e")
                    # Modify the task
                    task ${id} edit
                    ;;
                "c")
                    # Finish the task immediately
                    task ${id} done
                    break
                    ;;
                "n")
                    # Set it as a next action
                    task ${id} modify +next
                    break
                    ;;
                "s")
                    # Schedule the task (for myself)
                    task calendar
                    read -p "When? (YYYY-MM-DD | tomorrow | mon, tue | jan, feb): " WHEN < /dev/tty
                    task ${id} modify wait:${WHEN}
                    read -n 1 -p "Is there a deadline? [y/N]" IS_DEADLINE < /dev/tty
                    if [ "${IS_DEADLINE}" = "y" ]; then
                        read -p "When? (YYYY-MM-DD | tomorrow | mon, tue | jan, feb): " DEADLINE < /dev/tty
                        task ${id} modify due:${DEADLINE}
                    fi
                    break
                    ;;
                "p")
                    # Turn the task into a project.
                    PROJECTS=$(task _projects)
                    echo "Existing projects:"
                    echo ${PROJECTS}
                    echo
                    read -p "Project: " PROJECT < /dev/tty
                    task ${id} modify pro:${PROJECT}
                    break
                    ;;
                "b")
                    cal -A 2
                    read -p "When do you want to check in? (YYY-MM-DD | tomorrow | mon, tue | jan, feb): " WHEN < /dev/tty
                    task ${id} modify wait:${WHEN} +waiting
                    break
                    ;;
                "z")
                    # Snooze - put it in tomorrow's inbox
                    CONFIRM_SNOOZE="y"
                    if [ $(task ${id} | grep -e "Wait changed\|Wait set" | wc -l) -gt 5 ]; then
                        echo "Warning -- you've snoozed this task more than 5 times.";
                        read -n 1 -p "Are you sure? [y/N] " CONFIRM_SNOOZE < /dev/tty
                    fi

                    if [ "${CONFIRM_SNOOZE}" = "y" ]; then
                        task ${id} modify wait:tomorrow
                        break
                    fi
                    ;;
                "m")
                    task ${id} modify +someday
                    break
                    ;;
                "d")
                    yes | task ${id} delete
                    break
                    ;;
                "?")
                    usage_daily
                    ;;
                "")
                    task modify ${id} -in
                    break
                    ;;
                *)
                    break
                    ;;
            esac
        done
    done

}

process_weekly() {
    # enumerate the project names for all active projects.
    for project in $(task rc.list.all.projects=0 _projects)
    do
        # temporarily override the 'next' report output to yield only uuid, and only one task.
        uuid=$(task project="$project" rc.verbose=nothing rc.report.next.columns=uuid rc.report.next.labels=uuid limit:1 next)
        UUIDS="$UUIDS $uuid"
    done

    # Run the next report, showing only the specific list of tasks.
    task $UUIDS next

    for proj in $(task _projects); do
        task pro:$proj +next &> /dev/null || echo "$proj missing +next"
    done

    # Review +someday list
    task +someday

    # Review +waiting list
    task +waiting

    # Trigger lists
    echo "TODO: Trigger List"
}

case $1 in
    inbox)
        process_inbox
        ;;
    weekly)
        process_weekly
        ;;
    *)
        usage
        ;;
esac
