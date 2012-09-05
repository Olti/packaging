#!/bin/sh

#-------------------------------------------------------------------------------
# title			: mythtv-buildebuild.sh
# description	: This script will make a header for a bash script.
# author		: Christian Oltenburger <Christian@Oltenburger.de>
# date			: 20120728
# version		: 0.1    
# notes         : Install git to use this script.
# license		: GPL
#-------------------------------------------------------------------------------

# Uncomment this to enable deug output
#DEBUG=1

#-------------------------------------------------------------------------------
# Following definitions are essential for work of the script.
# You shouldn't change anything below here
#-------------------------------------------------------------------------------

# Definition of commandline options
OPTIONS=":b:p:l:"

# Repositories to update
REPOS="mythtv"

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

# Print the debug putput
# in: string to print
debug_echo()
{
	if [ "1" = "${DEBUG}" ]; then
		echo $@
	fi
}

#-------------------------------------------------------------------------------

# Print a usage message
# TODO Implement a proper usage message
usage()
{
	echo "Here will be a (usefull) usage message in future"
}

#-------------------------------------------------------------------------------

# Download the repository
# in: Name of repository
check_repo()
{
	base_dir=$1
	repo=$2

	if [ -z ${repo} ]; then
		return 1
	fi

	# Clone the repository from github if not existing
	if [ ! -d ${base_dir}/${repo} ]; then
		# Clone the repository if not allready existing
		git clone --bare https://github.com/MythTV/${repo} ${base_dir}/${repo}
	fi

	pushd ${base_dir}/${repo} 2>&1 > /dev/null

	# Check if it is a git repository
	GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
	if [ -z "$GIT_DIR" ]; then
		echo >&2 "This is not a git repository"
		return 1
	fi

	popd 2>&1 > /dev/null

	return 0
}

#-------------------------------------------------------------------------------

# Get information needed to create the ebuild
# in: Name of the repository
get_information()
{
	base_dir=$1
	repo=$2
	branch=$3

	if [ -d ${base_dir}/${repo} ]; then
		# Go to the cloned repo
		pushd ${base_dir}/${repo} 1>&2 > /dev/null

		# Find latest commit
		latest_commit=$(git rev-parse ${branch} 2> /dev/null)

		# Exit if the revision is unknown
		if [ $? -ne 0 ]; then
			echo "The specified revision is unknown" >&2

			return 1
		fi

		latest_commit_short=$(git --no-pager show -s --format="%h" ${latest_commit})
		commit_date=$(git --no-pager show -s --date=short --format="%cd" ${latest_commit} | sed -e s/-//g)

		git_version=$(git describe ${latest_commit_short})
		source_version=$(echo ${git_version} | sed -e 's/^v\([0-9.]*\).*/\1/g')

		# Get the version information
		major_version=$(echo ${source_version} | awk -F. '{ print $1 }')
		minor_version=$(echo ${source_version} | awk -F. '{ print $2 }')
		revision=$(echo ${source_version} | awk -F. '{ print $3 }')

		if [ -z ${PREFIX} ]; then
			if [ "master" = "${branch}" ]; then
				PREFIX="pre"
			else
				PREFIX="p"
			fi
		fi

		# debug output the information
		debug_echo "Gitversion: ${git_version}"
		debug_echo "Sourceversion: ${source_version}"
		debug_echo "Major: ${major_version}"
		debug_echo "Minor: ${minor_version}"
		debug_echo "Revision: ${revision}"
		debug_echo "Latest commit: ${latest_commit}"
		debug_echo "Latest commit short: ${latest_commit_short}"

		popd 1>&2 > /dev/null
	else
		return 1
	fi

	return 0
}

#-------------------------------------------------------------------------------

# Find the ebuild to use as a base and update it
# in: Package name
update_ebuild()
{
	package=$1

	if [ -z ${package} ]; then
		echo "Error in update_ebuild()"

		return 1
	fi

	# Find the ebuild to use as a base
	ebuild=$(find -iname "${package}-${source_version}*.ebuild" | tail -1)

	if [ -z ${ebuild} ]; then
		ebuild=$(find -iname "${package}-${major_version}.${minor_version}*.ebuild" | tail -1)
	fi

	if [ -z ${ebuild} ]; then
		ebuild=$(find -iname "${package}-*.ebuild" | tail -1)
	fi

	new_ebuild="$(dirname ${ebuild})/${package}-${source_version}_${PREFIX}${commit_date}.ebuild"

	# Exit if no ebuild is found
	if [ -z ${ebuild} ]; then
		return 1
	fi

	# Move ebuild to new name
	if [ "${ebuild}" != "${new_ebuild}" ]; then
		echo "${ebuild} -> ${new_ebuild}"

		git mv ${ebuild} ${new_ebuild}
	fi

	# Update the variables in the new ebuild file
	sed -i "s@^\(MYTHTV_VERSION=\).*@\1\"${git_version}\"@" ${new_ebuild} || return 1
	sed -i "s@^\(MYTHTV_BRANCH=\).*@\1\"${BRANCH}\"@" ${new_ebuild} || return 1
	sed -i "s@^\(MYTHTV_REV=\).*@\1\"${latest_commit}\"@" ${new_ebuild} || return 1
	sed -i "s@^\(MYTHTV_SREV=\).*@\1\"${latest_commit_short}\"@" ${new_ebuild} || return 1

	# Update the ebuild manifest
	ebuild ${new_ebuild} manifest 2>&1 > /dev/null || return 1

	return 0
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

# Default varibles
BRANCH="master"
PREFIX=""
STORAGE_LOCATION="/tmp"

# Exit if we are not in the Gentoo folder
if [ "$0" != "scripts/mythtv-buildebuild.sh" ]; then
	echo "You have to start this script from the Gentoo folder"
	exit 1
fi

# Parse the commandline options
while getopts "$OPTIONS" opt; do
	case $opt in
		b)
			BRANCH="$OPTARG"
			;;
		p)
			PREFIX="$OPTARG"
			;;
		l)
			STORAGE_LOCATION="$OPTARG"
			;;
		\?)
			usage
			exit 1
			;;
		:)
			usage
			exit 1
			;;
	esac
done

debug_echo "Configured branch: ${BRANCH}"
debug_echo "Configured prefix: ${PREFIX}"
debug_echo "Location of the base repository: ${STORAGE_LOCATION}"

# Download the repositories
for REPO in ${REPOS}; do
	check_repo ${STORAGE_LOCATION} ${REPO} || exit 1
	get_information ${STORAGE_LOCATION} ${REPO} ${BRANCH} || exit 1

	case ${REPO} in
		"mythtv")

			PLUGINS=""
			PLUGINS="${PLUGINS} mytharchive"
			PLUGINS="${PLUGINS} mythbrowser"
			PLUGINS="${PLUGINS} mythgame"
			PLUGINS="${PLUGINS} mythgallery"
			PLUGINS="${PLUGINS} mythmusic"
			PLUGINS="${PLUGINS} mythnetvision"
			PLUGINS="${PLUGINS} mythnews"
			if [ ${major_version} -eq 0 -a ${minor_version} -le 24 ]; then
				PLUGINS="${PLUGINS} mythvideo"
			fi
			PLUGINS="${PLUGINS} mythweather"
			PLUGINS="${PLUGINS} mythzoneminder"

			# Update the ebuilds
			for package in ${PLUGINS} "mythtv"; do
				update_ebuild ${package} || exit 1
			done
			;;
		*)
			exit 1
			;;
	esac
done

