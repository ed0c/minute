#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ_PATH="${PBXPROJ_PATH:-$ROOT_DIR/Minute.xcodeproj/project.pbxproj}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.roblibob.Minute}"

usage() {
  cat <<'EOF'
Usage:
  scripts/bump-version.sh --show
  scripts/bump-version.sh --bump-build
  scripts/bump-version.sh --set-version X.Y.Z [--no-build-bump]
  scripts/bump-version.sh --bump-version {major|minor|patch}

Options:
  --show                       Print current marketing/build version for the app target.
  --bump-build                 Increment CURRENT_PROJECT_VERSION by 1.
  --set-version X.Y.Z          Set MARKETING_VERSION to X.Y.Z (build bumps by default).
  --no-build-bump              Keep CURRENT_PROJECT_VERSION unchanged (only with --set-version).
  --bump-version part          Bump semantic version part and bump build by 1.
  --help                       Show this help.

Environment:
  PBXPROJ_PATH                 Path to project.pbxproj (default: Minute.xcodeproj/project.pbxproj).
  APP_BUNDLE_ID                Bundle ID to target (default: com.roblibob.Minute).
EOF
}

require_file() {
  if [[ ! -f "$PBXPROJ_PATH" ]]; then
    echo "error: project file not found: $PBXPROJ_PATH" >&2
    exit 1
  fi
}

read_current_versions() {
  awk -v bundle="$APP_BUNDLE_ID" '
  BEGIN {
    in_block = 0
    is_config = 0
    is_app = 0
    marketing = ""
    build = ""
  }

  function reset_block_state() {
    is_config = 0
    is_app = 0
    marketing = ""
    build = ""
  }

  function emit_if_app_block() {
    if (is_config && is_app && marketing != "" && build != "") {
      print marketing
      print build
      exit 0
    }
  }

  {
    if (!in_block && $0 ~ /^\t\t[A-F0-9]{24} .* = \{$/) {
      in_block = 1
      reset_block_state()
      next
    }

    if (in_block) {
      if ($0 ~ /isa = XCBuildConfiguration;/) {
        is_config = 1
      }
      if ($0 ~ ("PRODUCT_BUNDLE_IDENTIFIER = " bundle ";")) {
        is_app = 1
      }
      if ($0 ~ /MARKETING_VERSION = /) {
        line = $0
        sub(/^.*MARKETING_VERSION = /, "", line)
        sub(/;.*/, "", line)
        marketing = line
      }
      if ($0 ~ /CURRENT_PROJECT_VERSION = /) {
        line = $0
        sub(/^.*CURRENT_PROJECT_VERSION = /, "", line)
        sub(/;.*/, "", line)
        build = line
      }
      if ($0 ~ /^\t\t\};$/) {
        emit_if_app_block()
        in_block = 0
      }
      next
    }
  }

  END {
    exit 1
  }' "$PBXPROJ_PATH"
}

validate_semver() {
  local value="$1"
  if [[ ! "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: invalid semantic version '$value' (expected X.Y.Z)" >&2
    exit 1
  fi
}

validate_build_number() {
  local value="$1"
  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "error: invalid build number '$value' (expected integer)" >&2
    exit 1
  fi
}

bump_semver() {
  local current="$1"
  local part="$2"
  local major minor patch
  IFS=. read -r major minor patch <<<"$current"

  case "$part" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
    *)
      echo "error: invalid bump part '$part' (expected major|minor|patch)" >&2
      exit 1
      ;;
  esac

  echo "${major}.${minor}.${patch}"
}

write_versions() {
  local new_marketing="$1"
  local new_build="$2"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/minute-pbxproj.XXXXXX")"

  awk \
    -v bundle="$APP_BUNDLE_ID" \
    -v set_marketing="1" \
    -v set_build="1" \
    -v marketing="$new_marketing" \
    -v build="$new_build" '
  BEGIN {
    in_block = 0
    is_config = 0
    block = ""
  }

  function flush_block() {
    if (is_config && index(block, "PRODUCT_BUNDLE_IDENTIFIER = " bundle ";") > 0) {
      if (set_build == "1") {
        gsub(/CURRENT_PROJECT_VERSION = [^;]+;/, "CURRENT_PROJECT_VERSION = " build ";", block)
      }
      if (set_marketing == "1") {
        gsub(/MARKETING_VERSION = [^;]+;/, "MARKETING_VERSION = " marketing ";", block)
      }
    }
    printf "%s", block
  }

  {
    if (!in_block && $0 ~ /^\t\t[A-F0-9]{24} .* = \{$/) {
      in_block = 1
      is_config = 0
      block = $0 ORS
      next
    }

    if (in_block) {
      block = block $0 ORS
      if ($0 ~ /isa = XCBuildConfiguration;/) {
        is_config = 1
      }
      if ($0 ~ /^\t\t\};$/) {
        flush_block()
        in_block = 0
        is_config = 0
        block = ""
      }
      next
    }

    print
  }

  END {
    if (in_block) {
      flush_block()
    }
  }' "$PBXPROJ_PATH" >"$tmp"

  mv "$tmp" "$PBXPROJ_PATH"
}

mode=""
set_version=""
bump_part=""
no_build_bump="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --show)
      mode="show"
      shift
      ;;
    --bump-build)
      mode="bump-build"
      shift
      ;;
    --set-version)
      mode="set-version"
      if [[ $# -lt 2 ]]; then
        echo "error: --set-version requires a value" >&2
        exit 1
      fi
      set_version="$2"
      shift 2
      ;;
    --bump-version)
      mode="bump-version"
      if [[ $# -lt 2 ]]; then
        echo "error: --bump-version requires major|minor|patch" >&2
        exit 1
      fi
      bump_part="$2"
      shift 2
      ;;
    --no-build-bump)
      no_build_bump="1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$mode" ]]; then
  usage >&2
  exit 1
fi

if [[ "$mode" != "set-version" && "$no_build_bump" == "1" ]]; then
  echo "error: --no-build-bump is only valid with --set-version" >&2
  exit 1
fi

require_file

current_marketing=""
current_build=""
{
  IFS= read -r current_marketing || true
  IFS= read -r current_build || true
} < <(read_current_versions)

if [[ -z "$current_marketing" || -z "$current_build" ]]; then
  echo "error: failed to read current versions for bundle '$APP_BUNDLE_ID'" >&2
  exit 1
fi

validate_semver "$current_marketing"
validate_build_number "$current_build"

case "$mode" in
  show)
    echo "MARKETING_VERSION=$current_marketing"
    echo "CURRENT_PROJECT_VERSION=$current_build"
    exit 0
    ;;
  bump-build)
    new_marketing="$current_marketing"
    new_build="$((current_build + 1))"
    ;;
  set-version)
    validate_semver "$set_version"
    new_marketing="$set_version"
    if [[ "$no_build_bump" == "1" ]]; then
      new_build="$current_build"
    else
      new_build="$((current_build + 1))"
    fi
    ;;
  bump-version)
    new_marketing="$(bump_semver "$current_marketing" "$bump_part")"
    new_build="$((current_build + 1))"
    ;;
  *)
    echo "error: unsupported mode '$mode'" >&2
    exit 1
    ;;
esac

write_versions "$new_marketing" "$new_build"

echo "Updated $PBXPROJ_PATH"
echo "MARKETING_VERSION: $current_marketing -> $new_marketing"
echo "CURRENT_PROJECT_VERSION: $current_build -> $new_build"
