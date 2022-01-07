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

	fullVersion='5.8.2'
	
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
				phpVersions: [ "7.4", "7.3", "8.0", "8.1" ],
				variants: (
					if env.version == "cli" then
						[ "alpine" ]
					else
						[ "apache", "fpm", "fpm-alpine" ]
					end
				),
			} + $doc
		'
	)"
done

jq <<<"$json" -S . > versions.json