#!/usr/bin/env fish

# * bucket.fish

# ** Defaults
set bucket bucket  # Default bucket name
set dir ~/.cache/bucket
set deleteCommand trash-put
set expireDays 14

#set debug true


# ** Functions
function debug --description "Print debug message in yellow"
    # Do NOT use separate set_color commands, or else you risk
    # polluting later command substitutions!  See
    # https://github.com/fish-shell/fish-shell/issues/2378
    set -q debug
    and echo (set_color yellow)"DEBUG: $argv"(set_color normal) >&2
end
function die --description "Print error message and quit"
    echo (set_color red)"$argv"(set_color normal) >&2
    exit 1
end
function usage
    echo "bucket [OPTIONS] [BUCKET NAME]"
    echo
    echo "Reads from STDIN and writes to STDOUT"
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


# ** Check directory
if not test -d $dir
    # Make dir
    mkdir -p $dir
    or die "Unable to make bucket directory"
end

# cd just to be extra safe
cd $dir
or die "Unable to enter bucket directory"


# ** Args
while set optarg (getopts "a:append e:empty g:grep h:help l:list v:verbose V:VERBOSE x:expire" $argv)
    switch $optarg[1]
        case a
            set append true
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

# Bucket name
test -n "$optarg"; and set bucket $optarg

# Sanitize bucket name (since it's passed to eval and trash-put/rm)
set bucket (echo $bucket | sed -r 's/[~.]//g')

debug "Options: empty:$empty  verbose:$verbose  expire:$expire  bucket:$bucket"

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

    if set -q verbose
        for file in *
            echo -e (set_color blue)$file(set_color normal)": "(head -n1 $file)
        end

    else if set -q reallyVerbose
        for file in *
            echo -e (set_color blue)$file(set_color normal)":"
            cat $file
            echo
        end

    else
        ls
    end

else if set -q grep
    grep -i $grep *

else if set -q empty
    # *** Empty bucket
    if not test -f $dir/$bucket
        set -q verbose; and die "No such bucket"
    else
        eval "$deleteCommand $verbose "$dir/$bucket
    end

else if set -q expire
    # *** Expire buckets
    find $dir -type f -mtime $expireDays -exec $deleteCommand $verbose '{}' +

else
    if isatty stdin
        # STDIN is a tty; not filling bucket (pasting)

        # *** "Pour" (paste) bucket
        if not test -r $dir/$bucket
            set -q verbose; and die "No such bucket"
        else if not test -s $dir/$bucket
            set -q verbose; and die "Bucket is empty"

        else
            cat $dir/$bucket
        end

    else
        # STDIN is not a tty; filling bucket (copying)

        # *** Fill bucket
        if set -q append
            cat >>$dir/$bucket
        else
            cat >$dir/$bucket
        end

        set -q verbose; and cat $dir/$bucket
    end
end
