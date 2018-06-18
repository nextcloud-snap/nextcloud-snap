#!/bin/sh

tests_dir=$(CDPATH="" cd -- "$(dirname -- "$0")" && pwd)

run_shellcheck()
{
	checks=0
	failures=0
	while IFS= read -r file; do
		# Skip hidden files
		if expr "$(basename "$file")" : '^\.' > /dev/null; then
			continue
		fi

		checks=$((checks+1))
		if ! shellcheck -x "$file"; then
			failures=$((failures+1))
		fi
	done

	echo "Checked $checks files ($failures failed)"

	if [ $failures -gt 0 ]; then
		return 1
	fi

	return 0
}

grep -rl "^#!/bin/sh" "$tests_dir/../src/" | run_shellcheck
