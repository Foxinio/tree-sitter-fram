#! /usr/bin/env bash

tree-sitter generate

for f in $@; do
  if tree-sitter parse $f | grep -q "ERROR"; then
    echo "${f} failed."
  else
    echo "${f} passed."
  fi
done
