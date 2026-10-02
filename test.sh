#!/bin/bash
# 跑 FocusEngine 与 FocusStore 的单测。引擎文件不依赖 SwiftUI，所以不需要整个 App。
set -euo pipefail
cd "$(dirname "$0")"

OUT="$(mktemp -d)/focus-tests"
swiftc -O \
  -target "$(uname -m)-apple-macos26.0" \
  -o "$OUT" \
  Sources/FocusEngine.swift Sources/FocusStore.swift Sources/StatsAggregator.swift Sources/FocusCalendarMarker.swift Tests/main.swift
"$OUT"
