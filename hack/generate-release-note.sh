#!/bin/bash

#   Copyright The containerd Authors.

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

amd64tgz_pathName="$(find release -name content-*)"

amd64tgz_fileName="$(basename ${amd64tgz_pathName})"

cat <<-EOX
## Changes
(To be documented)

## About the tar archive
- ${amd64tgz_fileName} : mpproxy binary with golang source files

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
The binaries were built automatically on GitHub Actions.
The build log is available for 90 days: https://github.com/${1}/actions/runs/${2}

The sha256sum of the SHA256SUMS file itself is \`${3}\` .

EOX
