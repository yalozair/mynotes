#!/usr/bin/env bash
# بناء مفكرتي v1.0.3 لجميع المنصات (شغّله محلياً على كل نظام)
set -euo pipefail
VERSION="${1:-1.0.3}"
OUT="releases/v${VERSION}"
mkdir -p "$OUT"

flutter pub get

echo "[Android] APK..."
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/mofkarti-v${VERSION}-android.apk"

echo "[Web] ZIP..."
flutter build web --release
( cd build/web && zip -rq "../../$OUT/mofkarti-v${VERSION}-web.zip" . )

if [[ "$(uname -s)" == "Linux" ]]; then
  echo "[Linux] tar.gz..."
  flutter build linux --release
  tar -czf "$OUT/mofkarti-v${VERSION}-linux-x64.tar.gz" -C build/linux/x64/release bundle
fi

if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ -d /c/Windows ]]; then
  echo "[Windows] ZIP..."
  flutter build windows --release
  ( cd build/windows/x64/runner/Release && zip -rq "../../../../../$OUT/mofkarti-v${VERSION}-windows-x64.zip" . )
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[macOS] ZIP..."
  flutter build macos --release
  ( cd build/macos/Build/Products/Release && zip -rq "../../../../../$OUT/mofkarti-v${VERSION}-macos.zip" my_nots_flutter.app )
  echo "[iOS] يتطلب Xcode + Apple Developer..."
  # flutter build ipa --release
fi

echo "Done:"
ls -lh "$OUT"
