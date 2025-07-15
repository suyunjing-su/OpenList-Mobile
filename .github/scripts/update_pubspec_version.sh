#!/bin/bash

# 更新pubspec.yaml中的版本号以与OpenList主程序版本同步
# pubspec.yaml使用三段式版本号，Android版本号会自动添加时间戳

VERSION_FILE="$GITHUB_WORKSPACE/openlist_version"
PUBSPEC_FILE="$GITHUB_WORKSPACE/pubspec.yaml"

if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: openlist_version file not found"
    exit 1
fi

if [ ! -f "$PUBSPEC_FILE" ]; then
    echo "Error: pubspec.yaml file not found"
    exit 1
fi

# 读取OpenList版本号
OPENLIST_VERSION=$(cat "$VERSION_FILE")

# 去掉版本号前缀'v'
BASE_VERSION=${OPENLIST_VERSION#v}

echo "Updating pubspec.yaml version to: $BASE_VERSION"

# 使用sed更新pubspec.yaml中的版本号
# 保持build number为+1，只更新版本号部分（三段式）
sed -i "s/^version: [0-9]\+\.[0-9]\+\.[0-9]\++[0-9]\+.*/version: ${BASE_VERSION}+1 # 与OpenList主程序版本同步，Android版本号自动添加时间戳/" "$PUBSPEC_FILE"

echo "pubspec.yaml version updated successfully"