#!/usr/bin/env fish

complete -c bucket -Af -s a -l append
complete -c bucket -Af -s e -l edit
complete -c bucket -Af -s E -l empty
complete -c bucket -Af -s g -l grep
complete -c bucket -Af -s h -l help
complete -c bucket -Af -s l -l list
complete -c bucket -Af -s v -l verbose
complete -c bucket -Af -s V -l VERBOSE
complete -c bucket -Af -s x -l expire
complete -c bucket -f -a '(ls ~/.cache/bucket)'
