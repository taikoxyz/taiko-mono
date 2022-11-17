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

rm -rf temp.*
rm -rf main.pdf
cp main.tex temp.tex
pdflatex  -interaction=errorstopmode -halt-on-error temp.tex && (bibtex temp || true)
pdflatex  -interaction=errorstopmode -halt-on-error temp.tex
mv temp.pdf main.pdf
rm -rf temp.*
