#!/bin/bash

# * bucket.sh

# ** Defaults
bucket=bucket  # Default bucket name
dir=~/.cache/bucket
deleteCommand=trash-put
expireDays=14


# ** Functions
function debug {
    [[ $debug ]] && echo "DEBUG: $@" >&2
}
function die {
    echo "$@" >&2
    exit 1
}
function verbose {
    [[ $verbose ]] && echo "$@" >&2
}
function usage {
    echo "Usage:"
    echo "    command | bucket [OPTIONS] [BUCKET]"
    echo "    bucket [OPTIONS] [BUCKET] [DATA]"
    echo

    echo "The first form reads data from STDIN and writes to the default bucket,
or BUCKET if given.  The second form reads DATA and/or BUCKET from
arguments, writing to a bucket or printing a bucket's contents."

    echo
    echo "Options:"
    echo "    -a, --append                Append to bucket"
    echo "    -d, --date                  Sort by date"
    echo "    -e, --edit                  Edit bucket"
    echo "    -E, --empty                 Empty bucket"
    echo "    -g PATTERN, --grep PATTERN  Grep in buckets"
    echo "    -h, --help                  i can Haz cheezburger?"
    echo "    -l, --list                  List buckets"
    echo "    -v, --verbose               Verbose output"
    echo "    -V, --VERBOSE               VERY verbose output"
    echo "    -x, --expire                eXpire old buckets (default: +$expireDays days)"
    echo "    --directory DIRECTORY       Bucket storage directory"
}


# ** Args
args=$(getopt -o adDeEghlvVx -l "append,date,debug,edit,empty,grep,help,list,verbose,VERBOSE,expire,directory:" -n "bucket" -- "$@")
[[ $? -eq 0 ]] || exit 1

eval set -- "$args"

while true
do
    case "$1" in
        -a|--append)
            append=true ;;
        -d|--date)
            sort=-tr ;;
        -D|--debug)
            debug=true ;;
        -e|--edit)
            edit=true ;;
        -E|--empty)
            empty=true ;;
        -g|--grep)
            shift
            grep="$@"
            break ;;
        -h|--help)
            usage
            exit ;;
        -l|--list)
            list=true ;;
        -v|--verbose)
            verbose=-v ;;
        -V|--VERBOSE)
            verbose=-v
            reallyVerbose=true ;;
        -x|--expire)
            expire=true ;;
        --directory)
            shift
            customDir="$1"
            ;;
        --)
            # Remaining args
            shift
            args=("$@")
            numargs=${#args[@]}
            break ;;
    esac

    shift
done

# *** Check STDIN and bucket name
if ! [[ -t 0 ]]
then
    debug "Data from STDIN"

    stdin=true

    if [[ $numargs -eq 0 ]]
    then
        debug "No args; using default bucket"

    elif [[ $numargs -eq 1 ]]
    then
        debug "One arg; using bucket: $optarg"

        bucket=$args

    else
        debug "Multiple args; using bucket $optarg[1]"
        verbose "Ignoring extra arguments"

        bucket="${args[0]}"
    fi
else
    debug "No data from STDIN"

    if [[ $numargs -eq 0 ]]
    then
        debug "No args"

    elif [[ $numargs -eq 1 ]]
    then
        if [[ -f $dir/$args ]]
        then
            # Bucket exists with name; pour it
            bucket=$args

            debug "Using bucket $bucket; no data remaining in args"
        else
            # No such bucket; use args as data for default bucket
            data=$args

            debug "No bucket named '$args'; using args as data for default bucket"
        fi

    else
        # Multiple args
        bucket="${args[0]}"
        unset args[0]
        data="${args[@]}"

        debug "Using bucket $bucket; using $numargs remaining args as data"
    fi
fi

# **** Sanitize bucket name (since it's passed to eval and trash-put/rm)
bucket=$(echo "$bucket" | sed -r 's/[~.]//g')

# *** Check for conflicting args
if [[ $empty && $expire ]]
then
    conflicting=true
fi
if [[ $conflicting ]]
then
    die "Conflicting operations given."
fi

# ** Check directory
if [[ $customDir ]]
then
    # Custom bucket directory; don't make it
    [[ -d $customDir ]] || die "Directory doesn't exist: $customDir"

    dir=$customDir

else
    # Standard bucket directory; make it if necessary
    if ! [[ -d $dir ]]
    then
        # Make dir
        mkdir -p "$dir" || die "Unable to make bucket directory: $dir"
    fi
fi

# cd just to be extra safe
cd "$dir" || die "Unable to enter bucket directory: $dir"


# ** Main
if [[ $list ]]
then
    # *** List buckets
    readarray -t files <<<"$(ls $sort)"

    if [[ $verbose && ! $reallyVerbose ]]
    then
        for file in "${files[@]}"
        do
            echo "$file: $(head -n1 "$file")"
        done
    elif [[ $reallyVerbose ]]
    then
        for file in "${files[@]}"
        do
            echo "$file:"
            cat "$file"
            echo
        done
    else
        ls
    fi

elif [[ $grep ]]
then
    grep -i "$grep" ./*

elif [[ $edit ]]
then
    # *** Edit bucket
    eval "$EDITOR \"$dir/$bucket\""

elif [[ $empty ]]
then
    # *** Empty bucket
    debug "Emptying bucket..."

    if ! [[ -f $dir/$bucket ]]
    then
        verbose "No such bucket"
    else
        eval "$deleteCommand $verbose \"$dir/$bucket\""
    fi

elif [[ $expire ]]
then
    # *** Expire buckets
    find "$dir" -type f -mtime +$expireDays -exec "$deleteCommand $verbose" '{}' +

else
    if ! [[ $stdin || $data ]]
    then
        # *** Pour bucket
        debug "Pouring bucket..."

        if ! [[ -r $dir/$bucket ]]
        then
            verbose "No such bucket"
        elif ! [[ -s $dir/$bucket ]]
        then
            verbose "Bucket is empty"
        else
            cat "$dir/$bucket"
        fi

    else
        # *** Fill bucket
        debug "Filling bucket..."

        if [[ $stdin ]]
        then
            debug "Catting STDIN into bucket"

            if [[ $append ]]
            then
                cat >>"$dir/$bucket"
            else
                cat >"$dir/$bucket"
            fi

        else
            debug "Echoing data into bucket"

            if [[ $append ]]
            then
                echo "$data" >>"$dir/$bucket"
            else
                echo "$data" >"$dir/$bucket"
            fi

        fi

        # Display bucket if verbose
        [[ $verbose ]] && cat "$dir/$bucket"
    fi
fi
