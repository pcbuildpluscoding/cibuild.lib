# The MIT License
#
# Copyright (c) 2023 Peter A McGill

amd64tgz_pathName="$(find release -name cibuild-*)"

amd64tgz_fileName="$(basename ${amd64tgz_pathName})"

cat <<-EOX
## Changes
$(<releaseAsset/changes.txt)

## About the tar archive
- ${amd64tgz_fileName} : $(<releaseAsset/about.txt)

### How to Use
Extract the archive to a path like \`/usr/local/bin\` or \`~/bin\` .
<details><summary>tar Cxzvvf /usr/local/bin ${amd64tgz_fileName}</summary>
<p>

\`\`\`
$(tar tzvf ${amd64tgz_pathName})
\`\`\`
</p>
</details>

- - -
The release was built automatically on GitHub Actions.
The build log is available for 90 days: https://github.com/${1}/actions/runs/${2}

The sha256sum of the SHA256SUMS file itself is \`${3}\` .

EOX
