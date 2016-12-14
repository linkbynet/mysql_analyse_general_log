#!/bin/bash

cd $(dirname $0) || exit 1

out=$(mktemp)
if [ -z "$out" ]; then
	echo missing temp file
	exit 1
fi

echo "Test 1 only-at-end";
zcat general_log.test1.gz | perl ../mysql_analyse_general_log.pl --end='161205 16:08:56' --only-at-end &> $out
if [ $? -ne 0 ]; then
	echo bad return code
	cat $out
	exit 1
fi
if [ $(grep 161205 $out | wc -l) -ne 21 ]; then
	echo bad result for thread 161205
	cat $out
	exit 1
fi

echo "test 2 min-duration"
zcat general_log.test1.gz | perl ../mysql_analyse_general_log.pl --min-duration=1 &> $out
if [ $? -ne 0 ]; then
	echo bad return code
	cat $out
	exit 1
fi
if [ $(grep 'COMMIT / duration: 1' $out | wc -l) -ne 2 ]; then
	echo bad number of matched transaction
	cat $out
	exit 1
fi

# Add next tests here

echo "All tests OK"
rm $out
exit 0
