#!/bin/bash

GIT_REPO="https://github.com/OpenListTeam/OpenList.git"
TAG_NAME=$(git -c 'versionsort.suffix=-' ls-remote --exit-code --refs --sort='version:refname' --tags $GIT_REPO | tail -n 1 | cut -d'/' -f3)

echo "OpenList - ${TAG_NAME}"
rm -rf ./src
unset GIT_WORK_TREE
git clone --branch "$TAG_NAME" https://github.com/OpenListTeam/OpenList.git ./src
rm -rf ./src/.git

mv -f ./src/* ../
rm -rf ./src

cd ../
go mod edit -replace github.com/djherbis/times@v1.6.0=github.com/jing332/times@latest
