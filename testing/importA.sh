#!/bin/bash

set -e
[ -z "$DEBUG" ] || set -x;

usage() {
  echo "  ${0##*/} <git_source_path> <commit_msg> [-s| --release-spec-file -t|--release-tag] [-u|--set-upstream-branch]" >&2;
}

if [ "$1" = "-h" -o "$1" = "--help" ]; then
  usage
  cat >&2 <<EOS

  Arguments and options =>
  <git_src_path> is the relative or absolute path to the local git repository
  <commit_msg> is the git commit message for commital
  option --release-spec-file => release spec yaml file
  option --release-tag => release version tag in vX.X.X format
  option --set-upstream-branch => push upstream with the branch name argument

  Note : --release-spec-file and --release-tag are mutually inclusive

  you are prompted to confirm the 'git add -A' command
  if yes, you are prompted to confirm the 'git commit -m <commit_msg>' command
  if yes, you are prompted to confirm the 'git push origin' command 

EOS
  exit 0
fi

function isAFlag() {
  FLAG_TEST="${1%%[!-]*}"
  [ "$FLAG_TEST" = "--" -o "$FLAG_TEST" = "-" ]
}

if [ $# -eq 0 ]; then
  echo "invalid arguments, expected exactly one, got |$@|"
  exit 1
fi

if isAFlag "$1"; then
  echo "wrong position of flag $1 - flags must go after arguments"
  exit 1
fi

GIT_SRC_PATH="$1"
shift

if isAFlag "$1"; then
  echo "wrong position of flag $1 - flags must go after arguments"
  exit 1
fi

GIT_SRC_PATH="$1"
shift


echo "got release specs : $relspec"

echo "lib path : |${LIB_PATH}|"

. "${LIB_PATH}/copy.module"

CopyBranch "$relspec"

echo "setting release attributes ..."
fromDir=$(yq '.releaseSpec.fromDir' "$relspec")
aboutText=$(yq '.releaseSpec.about' "$relspec")
manifest=$(yq '.releaseSpec.manifest' "$relspec")
assetSpec=$(yq '.releaseSpec.assetSpec' "$relspec")

if [ ! -d $(realpath "$fromDir") ]; then
  echo "$fromDir does not exist, aborting ..."
  exit 1
fi

if [ ! -f "${fromDir}/${aboutText}" ]; then
  echo "$aboutText does not exist, aborting ..."
  exit 1
elif [ ! -f "${fromDir}/${manifest}" ]; then
  echo "$manifest does not exist, aborting ..."
  exit 1
elif [ ! -f "${fromDir}/${assetSpec}" ]; then
  echo "$assetSpec does not exist, aborting ..."
  exit 1
fi

cp "${fromDir}/${aboutText}" ./attrib/
cp "${fromDir}/${manifest}" ./attrib/
cp "${fromDir}/${assetSpec}" ./attrib/

yq -i ".releaseTag = \"$releaseTag\"" "./attrib/${manifest}"

