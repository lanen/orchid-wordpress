#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ "${#versions[@]}" -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	export version

	doc='{}'

	fullVersion=
	if [ "$version" = 'cli' ]; then
		possibleVersions=( $(
			git ls-remote --tags 'https://github.com/wp-cli/wp-cli.git' \
				| sed -r 's!^[^\t]+\trefs/tags/v([^^]+).*$!\1!g' \
				| sort --version-sort --reverse
		) )
		for possibleVersion in "${possibleVersions[@]}"; do
			url="https://github.com/wp-cli/wp-cli/releases/download/v${possibleVersion}/wp-cli-${possibleVersion}.phar.sha512"
			if sha512="$(wget -qO- "$url" 2>/dev/null)" && [ -n "$sha512" ]; then
				export sha512
				doc="$(jq <<<"$doc" -c '.sha512 = env.sha512')"
				fullVersion="$possibleVersion"
				break
			fi
		done
	else
		possibleVersion="5.8.2"
		if [ -n "$possibleVersion" ] && sha1="$(wget -qO- "https://github.com/lanen/WordPress/archive/refs/tags/$possibleVersion.tar.gz.sha1")" && [ -n "$sha1" ]; then
			fullVersion="$possibleVersion"
			export sha1 fullVersion
			doc="$(jq <<<"$doc" -c '.sha1 = env.sha1 | .upstream = env.fullVersion')"
			if [[ "$fullVersion" != *.*.* && "$fullVersion" == *.* && "$fullVersion" != *-* ]]; then
				fullVersion+='.0'
			fi
    else
       fullVersion="$possibleVersion"
       export sha1 fullVersion
		fi
	fi
	if [ -z "$fullVersion" ]; then
		echo >&2 "error: failed to find version for $version"
		exit 1
	fi
	echo "$version: $fullVersion"

	export fullVersion
	json="$(
		jq <<<"$json" -c --argjson doc "$doc" '
			.[env.version] = {
				version: env.fullVersion,
				phpVersions: [ "7.4", "7.3" ],
				variants: (
					if env.version == "cli" then
						[ "alpine" ]
					else
						[ "fpm-alpine" ]
					end
				),
			} + $doc
		'
	)"
done

jq <<<"$json" -S . > versions.json