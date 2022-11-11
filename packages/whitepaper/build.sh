#!/usr/bin/env bash

##
## Usage: build.sh
##


set -e

if grep '=========' main.tex
then
  echo "merge conflict?"
  exit 1
fi

rm -rf build
mkdir -p build
pdflatex -output-directory=build -interaction=errorstopmode -halt-on-error main.tex
mv build/main.pdf build/taiko-whitepaper.pdf