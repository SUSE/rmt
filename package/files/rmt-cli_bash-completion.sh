# Completion script for SUSE RMT: rmt-cli
#
# COMP_WORDS are all words in the current cli feed
# COMP_CWORD is the index of the most recent word in COMP_WORDS
# COMPREPLY is an array of words, which will be searched for possible
# completions, *after* _rmt-cli() exited

# main completion routine
_rmt-cli()
{
	COMPREPLY=()

	local current_word subcommand options depth

	current_word=${COMP_WORDS[COMP_CWORD]}
	subcommand=${COMP_WORDS[1]}
	options="sync products repos systems mirror import export version help"
	depth=1

	if [[ ${subcommand} =~ ^(sync|mirror|version)$ ]] ; then
		: # these subcommands can't currently be completed further
	elif _rmt-cli-default-completion "${options[@]}" $depth ; then
		:
	elif [[ ${subcommand} =~ ^(products|repos|systems|import|export)$ ]] ; then
		((depth++))
		_rmt-cli_$subcommand $depth
	fi
}

# parameter 1: completion options
# parameter 2: count of already handled words (`depth`)
_rmt-cli-default-completion()
{
	local options depth current_word

	options=$1
	depth=$2
	current_word=${COMP_WORDS[COMP_CWORD]}

	if [[ ${COMP_CWORD} == ${depth} ]] ; then
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
		return 0
	elif [[ ${COMP_WORDS[$depth]} == help && ${COMP_CWORD} == $((depth + 1)) ]] ; then
		COMPREPLY=( $(compgen -W "${options/help/}" -- ${current_word}) )
		return 0
	fi

	return 1
}

# subcommand completion routines
# all of these expect the count of already handled words (`depth`) as first parameter
_rmt-cli_products()
{
	local current_word options flags

	current_word=${COMP_WORDS[COMP_CWORD]}
	options="list enable disable help"
	flags="--all --csv --release-stage="

	if _rmt-cli-default-completion "${options[@]}" $1 ; then
		:
	elif [[ ${current_word} == -* && ${COMP_WORDS[*]} =~ enable ]] ; then
		COMPREPLY=( $(compgen -W "--all-modules" -- ${current_word}) )
	elif [[ ${current_word} == -* && ${COMP_WORDS[2]} =~ ^(list|ls)$ ]] ; then
		COMPREPLY=( $(compgen -W "${flags}" -- ${current_word}) )
		[[ $COMPREPLY == "--release-stage=" ]] && compopt -o nospace
	fi
}

_rmt-cli_repos()
{
	local current_word options flags depth

	current_word=${COMP_WORDS[COMP_CWORD]}
	options="list enable disable custom help"
	flags="--all --csv"
	depth=$1

	if _rmt-cli-default-completion "${options[@]}" $depth ; then
		:
	elif [[ ${COMP_CWORD} > 2 && ${COMP_WORDS[2]} == custom ]] ; then
		((depth++))
		_rmt-cli_repos_custom $depth
	elif [[ ${current_word} == -* && ${COMP_WORDS[2]} =~ ^(list|ls)$ ]] ; then
		COMPREPLY=( $(compgen -W "${flags}" -- ${current_word}) )
	fi
}

_rmt-cli_systems()
{
	local current_word options flags depth

	current_word=${COMP_WORDS[COMP_CWORD]}
	options="list help scc-sync"
	flags="--all --csv --limit="
	depth=$1
	if _rmt-cli-default-completion "${options[@]}" $depth ; then
		:
	elif [[ ${current_word} == -* && ${COMP_WORDS[2]} =~ ^(list|ls)$ ]] ; then
		COMPREPLY=( $(compgen -W "${flags}" -- ${current_word}) )
		[[ $COMPREPLY == "--limit=" ]] && compopt -o nospace
	fi
}

_rmt-cli_repos_custom()
{
	local current_word options flags

	current_word=${COMP_WORDS[COMP_CWORD]}
	options="list add enable disable remove products attach detach help"
	flags="--csv"

	if _rmt-cli-default-completion "${options[@]}" $1 ; then
		:
	elif [[ ${current_word} == -* && ${COMP_WORDS[3]} =~ ^(list|ls|products)$ ]] ; then
		COMPREPLY=( $(compgen -W "${flags}" -- ${current_word}) )
	fi
}

_rmt-cli_import()
{
	local current_word options

	current_word=${COMP_WORDS[COMP_CWORD]}
	options="data repos help"

	if _rmt-cli-default-completion "${options[@]}" $1 ; then
		:
	elif [[ ${COMP_CWORD} == 3 ]] ; then
		COMPREPLY=( $(compgen -f $current_word) )
	fi
}

_rmt-cli_export()
{
	local current_word options

	current_word=${COMP_WORDS[COMP_CWORD]}
	options="data settings repos help"

	if _rmt-cli-default-completion "${options[@]}" $1 ; then
		:
	elif [[ ${COMP_CWORD} == 3 ]] ; then
		COMPREPLY=( $(compgen -f ${current_word}) )
	fi
}

complete -F _rmt-cli rmt-cli
