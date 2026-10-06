#!/usr/bin/env bash
# ============================================================================
#  fetch_all.sh — скачать зависимости и проверить приложение «МС» headless
#
#  ВАЖНО: ЗАПУСКАЙТЕ НА МАШИНЕ С НОРМАЛЬНЫМ ИНТЕРНЕТОМ (домашний ПК, VPS,
#  Colab), НЕ на корпоративной (там VPN блокирует pub.dev и dl.google.com).
#  Работает на любой Linux x64.
#
#  РЕЖИМЫ:
#    bash fetch_all.sh                 -> лёгкий (~300 МБ): Flutter + pub-зависимости
#                                         + dart test / flutter analyze / flutter test.
#                                         Достаточно для headless-проверки логики и
#                                         статического анализа без устройства.
#    WITH_ANDROID=1 bash fetch_all.sh  -> полный (~3 ГБ): + JDK 17 + Android SDK
#                                         (platform-tools, build-tools, platform 35,
#                                         emulator, system-image x86_64) + AVD +
#                                         сборка debug-APK. Позволяет запустить
#                                         приложение в headless-эмуляторе.
#
#  РЕЗУЛЬТАТ: ОДИН файл dist/ms_deps_bundle.tar.gz  (перенести на машину сборки).
#  Colab: файл скачается в браузер в конце.
#
#  ИСПОЛЬЗОВАНИЕ (из корня проекта, где рядом core/ и ms_app/):
#    bash fetch_all.sh                  # лёгкий: зависимости + тесты (headless)
#    WITH_ANDROID=1 bash fetch_all.sh   # полный: + JDK17 + Android SDK + APK + эмулятор

#  Итоги:
#    dist/ms_app_debug.apk              — готовый APK (режим WITH_ANDROID=1)
#    dist/ms_reports/*.txt              — отчёты (тесты, analyze, сборка, sdkmanager)
#    dist/ms_deps_bundle.tar.gz         — бандл для переноса на другую машину
# ============================================================================
set -uo pipefail

WORK="$(pwd)"
# Flutter SDK: сначала ищем существующий (в проекте, в $HOME/flutter), иначе качаем.
FL=""
for _cand in "$WORK/flutter" "$HOME/flutter" "/flutter"; do
  [ -x "$_cand/bin/flutter" ] && FL="$_cand" && break
done
[ -n "$FL" ] || FL="$WORK/flutter"   # куда скачивать, если не найден
DIST="$WORK/dist"
PROJECT="$WORK"
WITH_ANDROID="${WITH_ANDROID:-0}"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mПРЕДУПРЕЖДЕНИЕ: %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mОШИБКА: %s\033[0m\n' "$*"; exit 1; }
stage_fail() { warn "$* (этап пропущен, продолжаем)"; }

[ "$(uname -m)" = "x86_64" ] || die "нужна Linux x64 (сейчас: $(uname -m))"
[ -d "$PROJECT/core" ] && [ -d "$PROJECT/ms_app" ] || \
  die "рядом со скриптом не найдены core/ и ms_app/ (запускайте из корня проекта)"

mkdir -p "$DIST/ms_reports"
FL_BIN="$FL/bin/flutter"

# ============================================================================
# 1) Flutter SDK
# ============================================================================
if [ -x "$FL_BIN" ]; then
  say "1. Flutter SDK: переиспользуем $FL"
else
  say "1. Flutter SDK: скачиваем последнюю stable"
  REL_JSON=""
  for base in "https://storage.googleapis.com/flutter_infra_release" \
              "https://storage.flutter-io.cn/flutter_infra_release"; do
    echo "  пробуем: $base"
    if curl -fsSL --connect-timeout 15 --max-time 120 -o /tmp/rel.json \
         "$base/releases/releases_linux.json"; then
      REL_JSON="/tmp/rel.json"; break
    fi
  done
  [ -n "$REL_JSON" ] || die "releases_linux.json не скачался"

  read -r VER ARCH BASE_URL SHA256 < <(python3 - "$REL_JSON" <<'EOF'
import json, sys
r = json.load(open(sys.argv[1]))
base = r.get("base_url", "https://storage.googleapis.com/flutter_infra_release/flutter")
for x in r["releases"]:
    if x["channel"] == "stable":
        print(x["version"], x["archive"], base, x.get("sha256", ""))
        break
EOF
)
  [ -n "$VER" ] || die "stable-версия не найдена"
  echo "  Flutter $VER, archive: $ARCH"

  TARBALL="$WORK/$(basename "$ARCH")"
  CN_URL="${BASE_URL/storage.googleapis.com/storage.flutter-io.cn}"
  for base in "$BASE_URL" "$CN_URL"; do
    [ -s "$TARBALL" ] && break
    URL="$base/$ARCH"
    echo "  URL: $URL"
    for i in 1 2 3 4 5; do
      curl -fSL --connect-timeout 20 --max-time 3600 -C - -o "$TARBALL" "$URL" && break
      echo "  попытка $i не удалась (скачано $(stat -c%s "$TARBALL" 2>/dev/null || echo 0) байт)"
    done
  done
  [ -s "$TARBALL" ] || die "SDK-архив не скачался"
  if [ -n "$SHA256" ] && command -v sha256sum >/dev/null; then
    ACTUAL="$(sha256sum "$TARBALL" | cut -d' ' -f1)"
    [ "$ACTUAL" = "$SHA256" ] && echo "  sha256: OK" || warn "sha256 не совпал: $ACTUAL"
  fi

  say "   распаковка SDK"
  rm -rf "$FL"; tar -xf "$TARBALL" -C "$WORK"
  [ -d "$FL" ] || die "после распаковки нет $FL"
fi
export PATH="$FL/bin:$PATH"
FL_VER="$(flutter --version 2>&1)" || die "flutter не запускается: $FL_VER"
printf '%s\n' "$FL_VER" | sed -n '1,4p'
flutter config --no-analytics >/dev/null 2>&1 || true

# ============================================================================
# 2) pub-зависимости
# ============================================================================
say "2. pub-зависимости (flutter pub get)"
for pkg in core ms_app; do
  ok=0
  for i in 1 2 3; do
    ( cd "$PROJECT/$pkg" && flutter pub get >"/tmp/pubget_$pkg.log" 2>&1 ) \
      && [ -f "$PROJECT/$pkg/.dart_tool/package_config.json" ] \
      && { ok=1; echo "  $pkg: OK"; break; } \
      || { echo "  $pkg: попытка $i не удалась (tail: $(tail -1 /tmp/pubget_$pkg.log))"; sleep 10; }
  done
  [ $ok = 1 ] || die "pub get ($pkg) упал — см. /tmp/pubget_$pkg.log"
done

# ============================================================================
# 3) Headless-проверки: тесты ядра + analyze + widget-тесты приложения
# ============================================================================
say "3. Headless-тесты и анализ"
( cd "$PROJECT/core" && dart test ) > "$DIST/ms_reports/dart_test_core.txt" 2>&1 \
  && echo "  dart test (core): OK" || echo "  dart test (core): ПРОВАЛЫ — см. отчёт"
tail -3 "$DIST/ms_reports/dart_test_core.txt"

( cd "$PROJECT/ms_app" && flutter analyze ) > "$DIST/ms_reports/flutter_analyze_ms_app.txt" 2>&1 \
  && echo "  flutter analyze: OK" || echo "  flutter analyze: замечания — см. отчёт"
tail -3 "$DIST/ms_reports/flutter_analyze_ms_app.txt"

if [ -d "$PROJECT/ms_app/test" ]; then
  ( cd "$PROJECT/ms_app" && flutter test ) > "$DIST/ms_reports/flutter_test_ms_app.txt" 2>&1 \
    && echo "  flutter test: OK" || echo "  flutter test: ПРОВАЛЫ — см. отчёт"
  tail -3 "$DIST/ms_reports/flutter_test_ms_app.txt"
else
  echo "  flutter test: пропущено (нет ms_app/test)"
fi

cp "$PROJECT/core/pubspec.lock"   "$DIST/ms_reports/core_pubspec.lock"   2>/dev/null || true
cp "$PROJECT/ms_app/pubspec.lock" "$DIST/ms_reports/ms_app_pubspec.lock" 2>/dev/null || true

# ============================================================================
# 4) Android SDK + JDK + эмулятор + APK (опционально)
# ============================================================================
ANDROID_SDK="$WORK/android-sdk"
AVD_NAME="ms"
if [ "$WITH_ANDROID" = "1" ]; then
  say "4. Android SDK + JDK + эмулятор"
  export ANDROID_HOME="$ANDROID_SDK" ANDROID_SDK_ROOT="$ANDROID_SDK"

  # --- JDK 17: без root (портативный Temurin в ./jdk), системный пакет — fallback
  JDK_DIR="$WORK/jdk"
  detect_jdk() {
    if command -v java >/dev/null && java -version 2>&1 | head -1 | grep -qE '"(17|2[0-9])'; then
      JDK_HOME="$(cd "$(dirname "$(readlink -f "$(command -v java)")")/.." && pwd)"; return 0
    fi
    local d
    for d in "$JDK_DIR"/jdk-17* "$HOME"/jdk-17*; do
      [ -x "$d/bin/java" ] && { JDK_HOME="$d"; return 0; }
    done
    return 1
  }
  if ! detect_jdk; then
    echo "  JDK 17 не найден — качаю Temurin 17 (портативный, ~190 МБ, без sudo)"
    mkdir -p "$JDK_DIR"
    curl -fSL --connect-timeout 20 --retry 3 -o /tmp/jdk17.tar.gz \
      "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse" \
      && tar -xzf /tmp/jdk17.tar.gz -C "$JDK_DIR" \
      || warn "Temurin не скачался — пробую системный пакет (нужен sudo)"
    if ! detect_jdk; then
      if command -v apt-get >/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq openjdk-17-jdk-headless \
          || warn "apt-установка JDK не удалась"
      elif command -v dnf >/dev/null; then
        sudo dnf install -y java-17-openjdk || warn "dnf-установка JDK не удалась"
      elif command -v yum >/dev/null; then
        sudo yum install -y java-17-openjdk || warn "yum-установка JDK не удалась"
      else
        warn "JDK 17/21 недоступен — без него APK не собрать"
      fi
      detect_jdk || warn "JDK так и не найден — APK не соберём"
    fi
  fi
  if [ -n "${JDK_HOME:-}" ] && [ -x "$JDK_HOME/bin/java" ]; then
    export JAVA_HOME="$JDK_HOME"
    export PATH="$JDK_HOME/bin:$PATH"
    echo "  JDK: $("$JDK_HOME/bin/java" -version 2>&1 | head -1)  [$JDK_HOME]"
  else
    warn "JDK не настроен"
  fi

  # cmdline-tools
  if [ ! -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo "  скачиваю cmdline-tools"
    curl -fSL --retry 3 -o /tmp/clt.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" \
      || warn "cmdline-tools не скачались (нет доступа к dl.google.com?)"
    if [ -s /tmp/clt.zip ]; then
      mkdir -p "$ANDROID_SDK/cmdline-tools"
      unzip -q -o /tmp/clt.zip -d /tmp/clt_extract
      rm -rf "$ANDROID_SDK/cmdline-tools/latest"
      mv /tmp/clt_extract/cmdline-tools "$ANDROID_SDK/cmdline-tools/latest"
    fi
  fi

  if [ -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo "  ставлю platform-tools, build-tools;35.0.0, platforms;android-35, emulator, system-image"
    yes | "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
    "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" \
        "platform-tools" "build-tools;35.0.0" "platforms;android-35" \
        "emulator" "system-images;android-35;google_apis;x86_64" \
        > "$DIST/ms_reports/sdkmanager.log" 2>&1 \
      || stage_fail "sdkmanager (см. $DIST/ms_reports/sdkmanager.log)"
    flutter config --android-sdk "$ANDROID_SDK" >/dev/null 2>&1 || true

    # AVD
    if [ -x "$ANDROID_SDK/cmdline-tools/latest/bin/avdmanager" ]; then
      echo "  создаю AVD ($AVD_NAME)"
      echo "no" | "$ANDROID_SDK/cmdline-tools/latest/bin/avdmanager" create avd \
          -n "$AVD_NAME" -k "system-images;android-35;google_apis;x86_64" \
          > "$DIST/ms_reports/avd.log" 2>&1 \
        || stage_fail "avdmanager (см. $DIST/ms_reports/avd.log)"
      mkdir -p "$HOME/.android/avd"
      [ -d "$HOME/.android/avd/$AVD_NAME.avd" ] && cp -r "$HOME/.android/avd/$AVD_NAME.avd" "$ANDROID_SDK/.avd_$AVD_NAME" 2>/dev/null || true
    fi
  else
    stage_fail "cmdline-tools недоступны — APK/эмулятор не соберём"
  fi

  # debug-APK
  say "4b. Сборка debug-APK"
  ( cd "$PROJECT/ms_app" && flutter build apk --debug ) \
    > "$DIST/ms_reports/flutter_build_apk.log" 2>&1 \
    && echo "  APK собран" || { echo "  сборка APK упала — см. flutter_build_apk.log"; tail -5 "$DIST/ms_reports/flutter_build_apk.log"; }
  APK="$PROJECT/ms_app/build/app/outputs/flutter-apk/app-debug.apk"
  [ -f "$APK" ] && cp "$APK" "$DIST/ms_app_debug.apk" \
    && echo "  -> dist/ms_app_debug.apk ($(du -h "$DIST/ms_app_debug.apk" | cut -f1))"
else
  echo "4. Android/эмулятор: пропущен (для включения: WITH_ANDROID=1)"
fi

# ============================================================================
# 5) Бандл: pub-кэш + отчёты + (android-sdk + APK) -> ОДИН файл
# ============================================================================
say "5. Формирую бандл"
PUBCACHE="${PUB_CACHE:-$HOME/.pub-cache}"
BUNDLE_ITEMS=()

if [ -d "$PUBCACHE" ]; then
  echo "  пакую pub-cache: $(du -sh "$PUBCACHE" 2>/dev/null | cut -f1)"
  BUNDLE_ITEMS+=("pubcache")
  tar -czf "$DIST/ms_pub_cache.tar.gz" -C "$(dirname "$PUBCACHE")" "$(basename "$PUBCACHE")"
fi
BUNDLE_ITEMS+=("ms_reports")

if [ "$WITH_ANDROID" = "1" ]; then
  [ -d "$ANDROID_SDK" ] && BUNDLE_ITEMS+=("android-sdk")
  [ -f "$DIST/ms_app_debug.apk" ] && BUNDLE_ITEMS+=("ms_app_debug.apk")
fi

# Собираем единый бандл из подготовленных артефактов
STAGE="$WORK/.bundle_stage"; rm -rf "$STAGE"; mkdir -p "$STAGE"
[ -f "$DIST/ms_pub_cache.tar.gz" ] && cp "$DIST/ms_pub_cache.tar.gz" "$STAGE/"
cp -r "$DIST/ms_reports" "$STAGE/"
[ "$WITH_ANDROID" = "1" ] && [ -d "$ANDROID_SDK" ] && cp -r "$ANDROID_SDK" "$STAGE/android-sdk"
[ "$WITH_ANDROID" = "1" ] && [ -f "$DIST/ms_app_debug.apk" ] && cp "$DIST/ms_app_debug.apk" "$STAGE/"

tar -czf "$DIST/ms_deps_bundle.tar.gz" -C "$STAGE" .
rm -rf "$STAGE"

echo
ls -lh "$DIST"
echo "  БАНДЛ: $DIST/ms_deps_bundle.tar.gz ($(du -h "$DIST/ms_deps_bundle.tar.gz" | cut -f1))"

# Colab: скачать в браузер
if [ -x /usr/local/bin/google-colab-tocurl ]; then
  say "Colab: скачиваю бандл в браузер"
  python3 - <<'EOF'
from google.colab import files
files.download("dist/ms_deps_bundle.tar.gz")
EOF
fi

say "Готово. Перенесите на машину сборки ОДИН файл: $DIST/ms_deps_bundle.tar.gz"
echo "  Внутри: ms_pub_cache.tar.gz (для pub get --offline), ms_reports/ (тесты),"
if [ "$WITH_ANDROID" = "1" ]; then
echo "  android-sdk/ (JDK-зависимый), ms_app_debug.apk."
else
echo "  (Android/эмулятор не включены — лёгкий режим.)"
fi
