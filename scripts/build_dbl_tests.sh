#! /usr/bin/env bash

dbl_test_suite=../dbl/test/ok/*
out_path=./test/corpus/dbl_suite.txt

> "$out_path"

for test_path in $dbl_test_suite; do 
  name=$(basename $test_path)
  cat >> $out_path <<EOF
=====
$name
:skip
=====
EOF
  cat $test_path >> $out_path
  cat >> $out_path <<EOF
-----
(source_file)

EOF
done
