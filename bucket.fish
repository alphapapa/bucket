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
    isset debug
    and echo (set_color yellow)"DEBUG: $argv"(set_color normal) >&2
    #and echo "DEBUG: $argv" >&2
end
function die --description "Print error message and quit"
    echo (set_color red)"$argv"(set_color normal) >&2
    #echo "$argv" >&2
    exit 1
end
function verbose --description "Print message if verbose"
    isset verbose
    or isset reallyVerbose
    and echo "$argv" >&2
end
function isset --description "Test if variables named by args are set"
    # "set -q" everywhere gets old
    set -q $argv
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
    echo "    -d, --date     Sort by date"
    echo "    -e, --edit     Edit bucket"
    echo "    -E, --empty    Empty bucket"
    echo "    -g, --grep     Grep in buckets"
    echo "    -h, --help     I can haz cheezburger?"
    echo "    -l, --list     List buckets"
    echo "    -v, --verbose  Verbose output"
    echo "    -V, --VERBOSE  VERY verbose output"
    echo "    -x, --expire   eXpire old buckets (default: +$expireDays days)"
    echo "    --directory    Bucket storage directory"
end


# ** Args
while set optarg (getopts "a:append d:date D:debug e:edit E:empty g:grep h:help l:list v:verbose V:VERBOSE x:expire directory:" $argv)
    switch $optarg[1]
        case a
            set append true
        case d
            set sort "-tr"
        case D
            set debug true
            debug "Debugging on"
        case e
            set edit true
        case E
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
        case directory
            set customDir $optarg[2]
            debug "Using custom directory: $customDir"
        case \*
            usage
            echo
            die "Unknown option: $optarg[1]"
    end
end

set args $optarg
set numargs (count $args)

# *** Check STDIN and bucket name
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
        if test -f $dir/$args
            # Bucket exists with name; pour it
            set bucket $args

            debug "Using bucket $bucket; no data remaining in args"
        else
            # No such bucket; use args as data for default bucket
            set data $args

            debug "No bucket named '$args'; using args as data for default bucket"
        end

    else
        # Multiple args
        set bucket $args[1]
        set -e args[1]
        set data $args

        debug "Using bucket $bucket; using $numargs remaining args as data"
    end
end

# **** Sanitize bucket name (since it's passed to eval and trash-put/rm)
set bucket (echo $bucket | sed -r 's/[~.]//g')

# *** Check for conflicting args
if begin; isset empty; and isset expire; end
    set conflicting true
end

if isset conflicting
    die "Conflicting operations given."
end


# ** Check directory
if isset customDir
    # Custom bucket directory; don't make it
    test -d $customDir
    or die "Directory doesn't exist: $customDir"

    set dir $customDir

else
    # Standard bucket directory; make it if necessary
    if not test -d $dir
        # Make dir
        mkdir -p $dir
        or die "Unable to make bucket directory: $dir"
    end
end

# cd just to be extra safe
cd $dir
or die "Unable to enter bucket directory: $dir"


# ** Main
if isset list
    # *** List buckets
    debug "Listing buckets"

    if isset verbose
        for file in (ls $sort)
            echo -e (set_color blue)$file(set_color normal)": " (head -n1 $file)
            #echo "$file:" (head -n1 $file)
        end
    else if isset reallyVerbose
        for file in (ls $sort)
            echo -e (set_color blue)$file(set_color normal)":"
            #echo "$file:"
            cat $file
            echo
        end
    else
        ls
    end

else if isset grep
    # *** Grep buckets
    debug "Grepping buckets"
    
    grep -i $grep *

else if isset edit
    # *** Edit bucket
    debug "Editing bucket"

    eval "$EDITOR \"$dir/$bucket\""
    
else if isset empty
    # *** Empty bucket
    debug "Emptying bucket $bucket"

    if not test -f "$dir/$bucket"
        verbose "No such bucket"
    else
        eval "$deleteCommand $verbose \"$dir/$bucket\""
    end

else if isset expire
    # *** Expire buckets
    debug "Expiring buckets"
    
    find $dir -type f -mtime $expireDays -exec $deleteCommand $verbose '{}' +

else
    if begin; not isset stdin; and not isset data; end
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

        if isset stdin
            debug "Catting STDIN"

            if isset append
                cat >>"$dir/$bucket"
            else
                cat >"$dir/$bucket"
            end

        else
            debug "Echoing data"
            
            if isset append
                echo $data >>"$dir/$bucket"
            else
                echo $data >"$dir/$bucket"
            end
        end

        # **** Display bucket if verbose
        isset verbose
        or isset reallyVerbose
        and cat "$dir/$bucket"
    end
end
