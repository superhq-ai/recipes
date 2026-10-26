#!/bin/bash
# Check that index.json and the recipe directories agree, and that every
# recipe.json parses and names the step files that exist. Needs jq.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
names="$(jq -r '.[].name' index.json)"

for name in $names; do
    dir="$name"
    if [ ! -f "$dir/recipe.json" ]; then
        echo "index.json lists $name but $dir/recipe.json is missing"
        fail=1
        continue
    fi
    spec_name="$(jq -r '.name' "$dir/recipe.json")"
    if [ "$spec_name" != "$name" ]; then
        echo "$dir/recipe.json has name $spec_name, index.json says $name"
        fail=1
    fi
    if ! printf '%s' "$spec_name" | grep -Eq '^[a-z0-9][a-z0-9._-]*$'; then
        echo "$dir: name $spec_name must match [a-z0-9][a-z0-9._-]*"
        fail=1
    fi
    for step in $(jq -r '.steps // ["build.sh"] | .[]' "$dir/recipe.json"); do
        if [ ! -f "$dir/$step" ]; then
            echo "$dir: step $step is listed but missing"
            fail=1
        fi
    done
    for svc in $(jq -r '.services // {} | keys[]' "$dir/recipe.json"); do
        if ! printf '%s' "$svc" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
            echo "$dir: service name $svc must match [a-z0-9][a-z0-9-]*"
            fail=1
        fi
        if [ "$(jq -r ".services[\"$svc\"].exec | type" "$dir/recipe.json")" != "array" ]; then
            echo "$dir: service $svc needs an exec array"
            fail=1
        fi
    done
done

for dir in */; do
    dir="${dir%/}"
    [ -f "$dir/recipe.json" ] || continue
    if ! printf '%s\n' "$names" | grep -qx "$dir"; then
        echo "$dir/recipe.json exists but $dir is not in index.json"
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "ok: $(printf '%s\n' "$names" | wc -l | tr -d ' ') recipe(s) valid"
