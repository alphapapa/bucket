#!/bin/bash

# * bucket.sh

# ** Defaults
bucket=bucket  # Default bucket name
dir=~/.cache/bucket
deleteCommand=trash-put
expireDays=14

#debug=true

# ** Functions
function debug {
    # Do NOT use separate set_color commands, or else you risk
    # polluting later command substitutions!  See
    # https://github.com/fish-shell/fish-shell/issues/2378
    [[ $debug ]] && echo "DEBUG: $@" >&2
}
function die {
    echo "$@" >&2
    exit 1
}
function usage {
    echo "bucket [OPTIONS] [BUCKET NAME]"
    echo
    echo "Options:"
    echo "    -a|--append   Append to bucket"
    echo "    -e|--empty    Empty bucket"
    echo "    -g|--grep     Grep in buckets"
    echo "    -h|--help     I can haz cheezburger?"
    echo "    -l|--list     List buckets"
    echo "    -v|--verbose  Verbose output"
    echo "    -V|--VERBOSE  VERY verbose output"
    echo "    -x|--expire   eXpire old buckets (default: +$expireDays days)"
}

# ** Check directory
if ! [[ -d $dir ]]
then
    # Make dir
    mkdir -p $dir || die "Unable to make bucket directory"
fi

# cd just to be extra safe
cd $dir || die "Unable to enter bucket directory"


# ** Args
args=$(getopt -o aeghlvVx -l "append,empty,grep,help,list,verbose,VERBOSE,expire" -n "bucket" -- "$@")
[[ $? -eq 0 ]] || exit 1

eval set -- "$args"

while true
do
    case "$1" in
        -a|--append)
            append=true ;;
        -e|--empty)
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
            verbose=true ;;
        -V|--VERBOSE)
            reallyVerbose=true ;;
        -x|--expire)
            expire=true ;;
        --)
            # Bucket name
            shift
            [[ $@ ]] && bucket="$@"
            break ;;
    esac

    shift
done

# Sanitize bucket name (since it's passed to eval and trash-put/rm)
bucket=$(echo "$bucket" | sed -r 's/[~.]//g')

debug "Options: append:$append  empty:$empty  grep:$grep  verbose:$verbose  reallyVerbose:$reallyVerbose  expire:$expire  bucket:$bucket"

# *** Check for conflicting args
if [[ $empty && $expire ]]
then
    conflicting=true
fi
if [[ $conflicting ]]
then
    die "Conflicting operations given."
fi


# ** Main
if [[ $list ]]
then
    # *** List buckets
    if [[ $verbose ]]
    then
        for file in *
        do
            echo "$file: $(head -n1 "$file")"
        done
    elif [[ $reallyVerbose ]]
    then
        for file in *
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

elif [[ $empty ]]
then
    # *** Empty bucket
    if ! [[ -f $dir/$bucket ]]
    then
        [[ $verbose ]] && die "No such bucket"
    else
        eval "$deleteCommand $verbose \"$dir/$bucket\""
    fi

elif [[ $expire ]]
then
    # *** Expire buckets
    find "$dir" -type f -mtime $expireDays -exec $deleteCommand $verbose '{}' +

else
    if [[ -t 0 ]]
    then
        # STDIN is a tty; not filling bucket (pasting)

        # *** "Pour" (paste) bucket
        if ! [[ -r $dir/$bucket ]]
        then
            [[ $verbose ]] && die "No such bucket"
        elif ! [[ -s $dir/$bucket ]]
        then
            [[ $verbose ]] && die "Bucket is empty"

        else
            cat "$dir/$bucket"
        fi

    else
        # STDIN is not a tty; filling bucket (copying)

        # *** Fill bucket
        if [[ $append ]]
        then
            cat >>"$dir/$bucket"
        else
            cat >"$dir/$bucket"
        fi

        [[ $verbose ]] && cat "$dir/$bucket"
    fi
fi
