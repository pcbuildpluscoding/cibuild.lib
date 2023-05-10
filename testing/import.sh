#!/bin/bash

jobId="$1"

manifest="$2"

importable=$(yq '.importable[]' "$manifest")

importable=($importable)

extractDir="/tmp/$jobId"

for item in "${importable[@]}"; do

  copyFrom=$(yq ".${item}.copyFrom"  "$manifest")
  copyTo=$(yq ".${item}.copyTo"  "$manifest")

  echo "cibuild/$item extract path : $copyFrom"
  echo "cibuild/$item package path : $copyTo"

  tmpPath="$extractDir/$copyFrom"

  if [ ! -d "$tmpPath" ]; then
    echo "$item extract directory does not exist at the required path : $tmpPath"
    exit 1
  fi

  echo "$item extract directory is found, proceeding to move the contents into cibuild/$item space"

  basePath="${copyTo%%/*}"

  if [ "$basePath" != "cmd" -a "$basePath" != "lib" -a "$basePath" != "genware" ]; then
    echo "base import directory is limited to either cmd, lib or genware - got : $basePath"
    exit 1
  fi

  pkgPath="$HOME/enterprise/cibuild/${copyTo}"

  echo "package path : $pkgPath"

  if [ -d "$pkgPath" ]; then
    echo "$pkgPath exists already"
  else
    echo "$pkgPath does not exist !!"
    mkdir -p "$pkgPath"
  fi

  cd $tmpPath

  for asset in *; do
    x="${asset%.*}"
    echo "extract file, package file : $asset, $pkgPath/${x}.go"
    cp "$asset" "$pkgPath/${x}.go"
  done

  echo "$copyFrom is imported successfully"
done

reltag=$(yq ".tag"  "$manifest")

echo "import of cibuild release $reltag is now done !"