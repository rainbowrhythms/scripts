#! /bin/bash
# A script to attach files to Taskwarriors tasks and open them on demand
# Original Author: Tomasz Żok

init_project() {
    base_dir=$1
    uuid=$2
    project_dir="$1/$2"
    mkdir -p $project_dir

    # If this is a project, create a symbolic link to the project ZK file in the new directory
    PROJECT_FILE=$(zk list --tag "project" --match "title: ${uuid}" --format path --delimiter " ")
    if [ ${PROJECT_FILE} ]
    then
        ln -s "${ZK_NOTEBOOK_DIR}/${PROJECT_FILE}" "$project_dir/00_$uuid.md"
    fi

    # Linked references
    PROJECT_REF_MATERIAL=$(zk list --linked-by ${PROJECT_FILE} --format path --delimiter " ")
    for REF in ${PROJECT_REF_MATERIAL}
    do
        mkdir -p "$project_dir/references"
        ln -s "${ZK_NOTEBOOK_DIR}/${REF}" "$project_dir/references/${REF}"
    done

    # Force export of next task list
    task project pro:${uuid} rc.report.project.columns=id,description > "$project_dir/01_tasks"
}

PROJECT_VIEW=false
if [[ "$1" == "-p" ]]
then
    PROJECT_VIEW=true
    shift
fi

# Check correctness of all input arguments
if [ $# -ne 1 -a $# -ne 2 ]
then
    echo 'Attach a file:       taskattach [-p] <ID|ProjectName> <PATH>'
    echo 'Open the attachment: taskattach [-p] <ID|ProjectName>'
    exit 1
elif [ $# -eq 2 -a ! -r "$2" ]
then
    echo "File is not readable: $2"
    exit 1
fi

if [ -z "$ZK_NOTEBOOK_DIR" ]
then
    echo "ZK_NOTEBOOK_DIR must be set"
    exit 1
fi

if $PROJECT_VIEW
then
    # Treat project name as uuid
    uuid=$(task _project "$1")
else
    # Get UUID of the task
    uuid=$(task "$1" uuid)
fi

if [ -z "$uuid" ]
then
    echo "Task with given id/project does not exist: $1"
    exit 1
fi

TASKATTACH_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/taskattach"
TARGET_DIR="${TASKATTACH_BASE}/$uuid"

# Unconditionally init the project, this will update any notes / tasks since we last looked
if [ $PROJECT_VIEW ]
then
    init_project $TASKATTACH_BASE $uuid
else
    mkdir -p ${TARGET_DIR}
fi

if [ $# -eq 1 ]
then
    target=$(find $TARGET_DIR -type l -o -type f | sort -h | fzf --layout=reverse --preview 'batcat --color=always {-1}')
    xdg-open $target
else
    # Change whitespace in filename to underscores
    filename=$(basename "$2")
    nowhitespace=$(echo "$filename" | sed 's/ /_/g')
    destination="$TARGET_DIR/$nowhitespace"
    test -e "$destination"
    exists=$?
    # Explicitly ask if the file of that name already exists
    cp --interactive "$2" "$destination"
    # Add annotation only if the attachment is a new one
    if [ ! $PROJECT_VIEW ] && [ $exists -ne 0 ]
    then
        task "$1" annotate "Attachment: $nowhitespace"
    fi
fi
