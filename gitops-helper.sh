#!/bin/sh

# Proof-of-concept budget SRE's GitOps helper script.
# Intended to be invoked by an application's CI job after all deploy tests
# pass in main branch, and later during multi-stage infrastructure pipelines.

# Yes, this is awkward and better done with a real delivery system like Jenkins-X,
# Weaveworks Flux, Argo CD, or Spinnaker (or one pipeline for all environments).
# I'm doing this the hard way to since I want to learn fundamentals, declare the
# state of my system in Git, and allow manual review for production deployments.

set -e # Exit if any commands fail

version="20191005.1"
usage="
Usage: $0 -s [service] -v [version] -u [URL] [-d] [-p]
	-h  display this help message
	-d  commit directly to main without a pull request branch (set GITHUB_TOKEN environment variable when using default branch mode)
	-p  promote new version/value to gated infrastructure pipeline (Jenkins job will submit pull request)
	-s  service (or Terraform variable key) to update
	-u  URL detailing this update (i.e. Jenkins job of originating application pipeline)
	-v  version (or Terraform variable value) to update
	-x  enable debug mode

$0 version: $version
"

# Set script defaults.
git_mode="branch"
promote="no"
environment="gated.tfvars"

# Assign variables based on supplied arguments.
while getopts ":hdps:u:v:x" option ; do
	case "$option" in
		h) echo "$usage" ; exit 0 ;;
		d) git_mode="direct" ;;
		p) promote="yes" ;;
		s) service="$OPTARG" ;;
		u) job_url="$OPTARG" ;;
		v) version="$OPTARG" ;;
		x) debug="yes" ;;
	esac
done

# Validate arguments and exit with error and usage information if missing or invalid options detected.

if [ -z "$version" ] ; then
	echo "Error: missing version (-v version)"
	echo "$usage"
	exit 1
fi

if [ -z "$service" ] ; then
	echo "Error: missing service (-s service)"
	echo "$usage"
	exit 1
fi

if [ -z "$job_url" ] ; then
	echo "Error: missing job information URL (-u http://joburl)"
	echo "$usage"
	exit 1
fi

if [ "$git_mode" == "branch" -a -z "$GITHUB_TOKEN" ] ; then
	echo "Error: missing GITHUB_TOKEN environment variable (required to create GitHub pull requests)"
	echo "$usage"
	exit 1
fi

if [ -n "$debug" ] ; then
	echo "Mode: $git_mode"
	echo "Promote: $promote"
	echo "Service: $service"
	echo "Version: $version"
	echo "Job URL: $job_url"
	echo ""
fi

# Confirm requested service/component exists in environment definition.
if ! grep -q "^${service}_version\ .*= " ${environment} ; then
	echo "Error: service $service not defined in $environment"
	exit 1
fi

# Abort if requested new version is identical to existing version.
old_version=`awk -F = "/^${service}_version/{gsub(/[ |\"]/, \"\"); print \\$NF}" ${environment}`
if [ "$old_version" == "$version" ] ; then
	echo "Error: $service version already $version"
	exit 1
fi

# Abort if we intend to promote this update to the gated pipeline when there's
# already a pending update in our working branch. This is clumsy and inelegant,
# but better than getting into a race condition with colliding upgrades.
if [ "$promote" == "yes" ] ; then
	git checkout scoreboard
	git pull origin scoreboard
	mkdir -p scoreboard/
	pending_updates=`ls -1 scoreboard/ | wc -l`
	if [ $pending_updates -gt 0 ] ; then
		echo "Error: cannot submit promotion request due to pending update: `ls -1 scoreboard`"
		exit 1
	fi
	echo "${service} ${version} ${job_url}" > scoreboard/${service}-${version}
	git add scoreboard/${service}-${version}
	git commit -m "Add lock for update of $service to $version"
	git push -u origin scoreboard
	git checkout main
	git reset --hard origin/main
fi

# Create a new branch if we're operating in pull request mode, otherwise update main directly.
if [ "$git_mode" == "branch" ] ; then
	git checkout -b ${service}-${version}
else
	git checkout main
fi

# Update component version with cutting edge DevOps string manipulation techniques.
sed -i -e "s/^\(${service}_version\ .*=\).*$/\1 \"${version}\"/" ${environment}
git add ${environment}

if [ "$promote" == "yes" ] ; then
	git commit -m "[PROMOTE] Request update of $service to $version"
else
	git commit -m "Request update of $service to $version"
fi

# Push our branch and submit pull request if operating in pull request mode, otherwise update main directly.
if [ "$git_mode" == "branch" ] ; then
	git push -u origin ${service}-${version}
	hub pull-request -m "Request update of $service to $version" -m "Details about this version are available at: $job_url"
else
	git push -u origin main
fi