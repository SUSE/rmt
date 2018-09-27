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

	local current_word subcommand options

	current_word=${COMP_WORDS[COMP_CWORD]} subcommand=${COMP_WORDS[1]}

	options="sync products repos mirror import export version help"

	# no subcommands yet:
	if [[ ${COMP_CWORD} == 1 ]] ; then
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
		return 0
	fi

	# subcommands:
	if [[ ${subcommand} =~ ^(sync|mirror|version)$ ]] ; then
		: # no further completion
	elif [[ ${subcommand} == help && ${COMP_CWORD} < 3 ]] ; then
		# show options without 'help'
		COMPREPLY=( $(compgen -W "${options/help/}" -- ${current_word}) )
	elif [[ ${subcommand} =~ ^(product|products|repo|repos|import|export)$ ]] ; then
		_rmt-cli_$subcommand
	fi
}

# subcommand completion routines
_rmt-cli_products()
{
	local current_word previous_word options flags

	current_word=${COMP_WORDS[COMP_CWORD]}
	previous_word=${COMP_WORDS[COMP_CWORD-1]}

	options="list enable disable"
	flags="--all --csv"

	if [[ ${COMP_CWORD} == 2 ]] ; then
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 3 && $previous_word =~ ^(enable|disable)$ ]] ; then
		options=$(_rmt-cli_string_of_products $previous_word)
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${current_word} == -* && ${COMP_WORDS[*]} =~ list ]] ; then
		COMPREPLY=( $(compgen -W "${flags}" -- ${current_word}) )
	fi
}

_rmt-cli_repos()
{
	local current_word options custom_options flags

	current_word=${COMP_WORDS[COMP_CWORD]}
	previous_word=${COMP_WORDS[COMP_CWORD-1]}

	options="list enable disable custom"
	custom_options="list add enable disable remove products attach detach"
	flags="--all --csv"

	if [[ ${COMP_CWORD} == 2 ]] ; then
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 3 && $previous_word =~ ^(enable|disable)$ ]] ; then
		options=$(_rmt-cli_string_of_repos $previous_word)
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} > 2 && ${COMP_WORDS[2]} == custom ]] ; then
		_rmt-cli_repos_custom
	elif [[ ${current_word} == -* && ${COMP_WORDS[2]} == list ]] ; then
		COMPREPLY=( $(compgen -W "${flags}" -- ${current_word}) )
	fi
}

_rmt-cli_repos_custom()
{
	local current_word options flags

	current_word=${COMP_WORDS[COMP_CWORD]}
	previous_word=${COMP_WORDS[COMP_CWORD-1]}

	options="list add enable disable remove products attach detach"
	flags="--csv"

	if [[ ${COMP_CWORD} == 3 ]] ; then
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 4 && $previous_word =~ ^(enable|disable)$ ]] ; then
		options=$(_rmt-cli_string_of_repos $previous_word custom)
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 4 && ${COMP_WORDS[3]} =~ ^(attach|remove)$ ]] ; then
		options=$(_rmt-cli_string_of_repos all custom)
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 4 && ${COMP_WORDS[3]} =~ ^(detach|products)$ ]] ; then
		options=$(_rmt-cli_repos_with_attached_products)
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 5 && ${COMP_WORDS[3]} == detach ]] ; then
		options=$(_rmt-cli_attached_products ${COMP_WORDS[4]})
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 5 && ${COMP_WORDS[3]} == attach ]] ; then
		options=$(_rmt-cli_string_of_products all)
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${current_word} == -* && ${COMP_WORDS[*]} =~ ^(list|products)$ ]] ; then
		[[ ${COMP_WORDS[*]} =~ custom ]] && flags="--csv"
		COMPREPLY=( $(compgen -W "${flags}" -- ${current_word}) )
	fi
}

_rmt-cli_import()
{
	local current_word options

	current_word=${COMP_WORDS[COMP_CWORD]}
	options="data repos"

	if [[ ${COMP_CWORD} == 2 ]] ; then
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 3 ]] ; then
		COMPREPLY=( $(compgen -f $current_word) )
	fi
}

_rmt-cli_export()
{
	local current_word options

	current_word=${COMP_WORDS[COMP_CWORD]}
	options="data settings repos"

	if [[ ${COMP_CWORD} == 2 ]] ; then
		COMPREPLY=( $(compgen -W "${options}" -- ${current_word}) )
	elif [[ ${COMP_CWORD} == 3 ]] ; then
		COMPREPLY=( $(compgen -f ${current_word}) )
	fi
}

# wrapper functions:
_rmt-cli_repo()
{
	_rmt-cli_repos
}

_rmt-cli_product()
{
	_rmt-cli_products
}

# helper functions:
# parameter: enable/disable/all
_rmt-cli_string_of_products()
{
	local products answer IFS_backup product i flags

	IFS_backup=$IFS

	answer=""

	flags=(--csv)
	[[ $1 == enable || $1 == all ]] && flags=(--all ${flags[@]})

	IFS=$'\n'
	products=( $(rmt-cli products list ${flags[@]} 2>/dev/null) )

	IFS=$','
	for i in "${products[@]}"; do
		product=( $i )
		# when already enabled:
		[[ $1 == enable && ${product[6]} == true ]] && continue
		# attach/detach don't work with product names:
		[[ $1 == all ]] && product[4]=""
		answer="$answer ${product[0]} ${product[4]}"
	done

	IFS=$IFS_backup
	echo -n "$answer"
}

# parameter 1: enable/disable/all
# parameter 2: custom/ ""
_rmt-cli_string_of_repos()
{
	local repos answer IFS_backup repo i flags

	IFS_backup=$IFS

	answer=""

	flags=(--csv)
	# custom repos don't support --all flag:
	[[ $1 == enable && $2 != custom ]] && flags=(--all ${flags[@]})
	[[ $1 == all && $2 != custom ]] && flags=(--all ${flags[@]})

	IFS=$'\n'
	repos=( $(rmt-cli repos $2 list ${flags[@]} 2>/dev/null) )

	IFS=$','
	for i in "${repos[@]}"; do
		repo=( $i )
		# when already enabled:
		[[ $1 == enable && ${repo[4]} == true ]] && continue
		# custom repos always list all repos, so we have to check manually:
		[[ $1 == disable && ${repo[4]} == false ]] && continue
		answer="$answer ${repo[0]}"
	done

	IFS=$IFS_backup
	echo -n "$answer"
}

# parameter 1: id of custom repo
_rmt-cli_attached_products()
{
	local attached_products attached_product answer IFS_backup

	IFS_backup=$IFS

	answer=""

	IFS=$'\n'
	attached_products=( $(rmt-cli repos custom products --csv $1 2>/dev/null) )

	IFS=$','
	for i in "${attached_products[@]}"; do
		attached_product=( $i )
		answer="$answer ${attached_product[0]}"
	done

	IFS=$IFS_backup
	echo -n "$answer"
}

_rmt-cli_repos_with_attached_products()
{
	local answer custom_repos attached_products repo

	answer=""
	custom_repos=$(_rmt-cli_string_of_repos all custom)

	for repo in $custom_repos; do
		attached_products="$(_rmt-cli_attached_products $repo 2>/dev/null)"
		[[ $attached_products == "" ]] && continue
		answer="$answer ${repo}"
	done

	echo -n "$answer"
}

complete -F _rmt-cli rmt-cli
