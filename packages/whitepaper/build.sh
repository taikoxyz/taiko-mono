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
pdflatex  -interaction=batchmode -halt-on-error temp.tex && (bibtex temp || true)
pdflatex  -interaction=batchmode -halt-on-error temp.tex
mv temp.pdf whitepaper_2_0.pdf
rm -rf temp.*
