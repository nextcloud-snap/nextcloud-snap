#!/bin/sh -e

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
		if shellcheck -x "$file"; then
			printf '.'
		else
			printf 'F'
			failures=$((failures+1))
		fi
	done

	printf '\n'
	echo "Checked $checks files ($failures failed)"

	if [ $failures -gt 0 ]; then
		return 1
	fi

	return 0
}

run_static_tests()
{
	grep -rl "^#!/bin/sh" "$tests_dir" "$tests_dir/../src/" | run_shellcheck
}

run_unit_tests()
{
	[ ! -f "$HOME/.local/bin/shellspec" ] && curl -fsSL https://git.io/shellspec | sh -s 0.28.1 -y
	"$HOME/.local/bin/shellspec" --helperdir "$tests_dir/unit" --default-path "$tests_dir/unit" --load-path "$tests_dir/unit"
}

run_integration_tests()
{
	(cd "$tests_dir" && rake test)
}

if [ $# = 0 ]; then
	suite="all"
elif [ $# = 1 ]; then
	suite="$1"
	shift
else
	echo "Usage:"
	echo "    run-tests.sh [all | static | unit | integration]"
	exit 1
fi

static=false
unit=false
integration=false

case "$suite" in
	static)
		static=true
		;;
	unit)
		unit=true
		;;
	integration)
		integration=true
		;;
	all)
		static=true
		unit=true
		integration=true
		;;
	*)
		echo "Invalid test suite: '$suite'" >&2
		exit 1
		;;
esac

[ "$static" = true ] && run_static_tests
[ "$unit" = true ] && run_unit_tests
[ "$integration" = true ] && run_integration_tests
exit 0
