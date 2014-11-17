#!/usr/bin/env bash

rm -rf dist
broccoli build dist

if [ -d dist ]; then
  mv dist/**/*.js .
fi
