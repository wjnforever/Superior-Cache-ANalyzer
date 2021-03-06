#!/bin/bash

lintResults="$(pylint --rcfile='./.pylintrc' scan/ 2>/dev/null)"
score=$(echo "$lintResults" | grep 'Your code has been rated at' | sed -r 's/[ a-zA-Z]//g' | cut -d '/' -f1)

if [[ -z "$score" || $(echo "$score<9.50" | bc -l) -ne 0  ]]; then
	echo "$lintResults" >&2
	exit 1
fi

echo "$lintResults"

if [[ ! -z "$(which git 2>/dev/null)" && ! -z "$(which cc 2>/dev/null)" && ! -z "$(which autoreconf 2>/dev/null)" && ! -z "$(which make 2>/dev/null)" ]]; then
	if [[ ! -d ats_test/goal ]]; then
		git clone https://github.com/apache/trafficserver.git ats_test
		pushd >/dev/null ats_test
		git checkout 7.1.x

		autoreconf -if || { echo "'autoreconf' has failed." >&2; exit 2; }

		mkdir goal

		./configure --prefix "$(pwd)/goal" || { echo "'./configure' has failed." >&2; exit 2; }

		make -j || { echo "'make' has failed." >&2; exit 2; }

		make install || { echo "'make install' has failed." >&2; exit 2; }

		for i in $(ls -A); do
			case $i in
				goal | tests )
					;;
				* )
					rm -rf "$i";
					;;
			esac
		done

		mkdir -p "tests/gold_tests/scan/gold"

		cp -f ../tests/*.py "tests/gold_tests/scan/"
		cp -f "../tests/cache_populated.gold" "tests/gold_tests/scan/gold/"
	else
		pushd >/dev/null ats_test
	fi

	autest -D tests/gold_tests --ats-bin goal/bin --show-color -f scan || { echo "Autests failed..." >&2; cat _sandbox/scan/_tmp_scan_1-general_Default/stream.all.txt; popd; exit 2; }

	popd >/dev/null

else
	echo "Cannot run autests, need git, make, autoconf and a C compiler (and ATS dependencies)" >&2
fi
