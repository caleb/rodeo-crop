#!/usr/bin/env bash

rm -rf dist
broccoli build dist
mv dist/**/*.js .
