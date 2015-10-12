#!/usr/bin/env fish

# * bucket.fish

# ** Defaults
set bucket bucket  # Default bucket name
set dir ~/.cache/bucket
set deleteCommand trash-put
set expireDays 14


# ** Functions
function debug --description "Print debug message in yellow"
    # Do NOT use separate set_color commands, or else you risk
    # polluting later command substitutions!  See
    # https://github.com/fish-shell/fish-shell/issues/2378
    set -q debug
    and echo (set_color yellow)"DEBUG: $argv"(set_color normal) >&2
    #and echo "DEBUG: $argv" >&2
end
function die --description "Print error message and quit"
    echo (set_color red)"$argv"(set_color normal) >&2
    #echo "$argv" >&2
    exit 1
end
function verbose --description "Print message if verbose"
    set -q verbose; and echo "$argv" >&2
end
function usage
    echo "Usage:"
    echo "    command | bucket [OPTIONS] [BUCKET]"
    echo "    bucket [OPTIONS] [BUCKET] [DATA]"
    echo

    echo "The first form reads data from STDIN and writes to the default bucket,
or BUCKET if given.  The second form reads DATA and/or BUCKET from
arguments, writing to a bucket or printing a bucket's contents."

    echo
    echo "Options:"
    echo "    -a, --append   Append to bucket"
    echo "    -e, --empty    Empty bucket"
    echo "    -g, --grep     Grep in buckets"
    echo "    -h, --help     I can haz cheezburger?"
    echo "    -l, --list     List buckets"
    echo "    -v, --verbose  Verbose output"
    echo "    -V, --VERBOSE  VERY verbose output"
    echo "    -x, --expire   eXpire old buckets (default: +$expireDays days)"
end


# ** Args
while set optarg (getopts "a:append d:debug e:empty g:grep h:help l:list v:verbose V:VERBOSE x:expire" $argv)
    switch $optarg[1]
        case a
            set append true
        case d
            set debug true
            debug "Debugging on"
        case e
            set empty true
        case g
            set -e optarg[1]
            set grep "$optarg"  # Flatten list
            break
        case h
            usage
            exit
        case l
            set list true
        case v
            set verbose -v
        case V
            set reallyVerbose true
        case x
            set expire
        case \*
            usage
            echo
            die "Unknown option: $optarg[1]"
    end
end

set args $optarg
set numargs (count $args)

# ** Check directory
if not test -d $dir
    # Make dir
    mkdir -p $dir
    or die "Unable to make bucket directory"
end

# cd just to be extra safe
cd $dir
or die "Unable to enter bucket directory"


# ** Actions
if not isatty stdin
    debug "Data from STDIN"

    set stdin true

    if test $numargs -eq 0
        debug "No args; using default bucket"

    else if test $numargs -eq 1
        debug "One arg; using bucket: $args"

        set bucket $args

    else
        debug "Multiple args; using bucket $args[1]"
        verbose "Ignoring extra arguments"

        set bucket $args[1]
    end
else
    debug "No data from STDIN"

    if test $numargs -eq 0
        debug "No args"

    else if test $numargs -eq 1
        # One arg
        set bucket $args

        debug "Using bucket $bucket; no data remaining in args"

    else
        # Multiple args
        set bucket $args[1]
        set -e args[1]
        set data $args

        debug "Using bucket $bucket; using $numargs remaining args as data"
    end
end

# Sanitize bucket name (since it's passed to eval and trash-put/rm)
set bucket (echo $bucket | sed -r 's/[~.]//g')

# *** Check for conflicting args
if begin; set -q empty; and set -q expire; end
    set conflicting true
end

if set -q conflicting
    die "Conflicting operations given."
end


# ** Main
if set -q list
    # *** List buckets
    debug "Listing buckets"

    if set -q verbose
        for file in *
            echo -e (set_color blue)$file(set_color normal)": "(head -n1 $file)
            #echo "$file:" (head -n1 $file)
        end
    else if set -q reallyVerbose
        for file in *
            echo -e (set_color blue)$file(set_color normal)":"
            #echo "$file:"
            cat $file
            echo
        end
    else
        ls
    end

else if set -q grep
    # *** Grep buckets
    debug "Grepping buckets"
    
    grep -i $grep *

else if set -q empty
    # *** Empty bucket
    debug "Emptying bucket $bucket"

    if not test -f "$dir/$bucket"
        verbose "No such bucket"
    else
        eval "$deleteCommand $verbose \"$dir/$bucket\""
    end

else if set -q expire
    # *** Expire buckets
    debug "Expiring buckets"
    
    find $dir -type f -mtime $expireDays -exec $deleteCommand $verbose '{}' +

else
    if begin; not set -q stdin; and not set -q data; end
        # *** Pour bucket
        debug "Pouring bucket..."
        
        if not test -r "$dir/$bucket"
            verbose "No such bucket"
        else if not test -s "$dir/$bucket"
            verbose "Bucket is empty"
        else
            cat "$dir/$bucket"
        end

    else
        # *** Fill bucket
        debug "Filling bucket..."

        if set -q stdin
            debug "Catting STDIN"

            if set -q append
                cat >>"$dir/$bucket"
            else
                cat >"$dir/$bucket"
            end

        else
            debug "Echoing data"
            
            if set -q append
                echo $data >>"$dir/$bucket"
            else
                echo $data >"$dir/$bucket"
            end
        end

        # **** Display bucket if verbose
        verbose (cat "$dir/$bucket")
    end
end
