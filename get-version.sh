#!/bin/sh
# 生成 tipa / control 版本号；无 git tag 时回退到 1.0.0
VERSION=$(git describe --tags --always --match "v*" 2>/dev/null | sed 's/^v//')
if [ -z "$VERSION" ] || [ "$VERSION" = "HEAD" ]; then
    VERSION="1.0.0"
fi
echo "$VERSION"
