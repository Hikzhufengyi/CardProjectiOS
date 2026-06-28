#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/VisaPhotoMaker.xcodeproj"
PROJECT_FILE="${PROJECT_PATH}/project.pbxproj"
SCHEME="${SCHEME:-VisaPhotoMaker}"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${TEAM_ID:-MAH98XTZBR}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d)}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
OUTPUT_ROOT="${OUTPUT_ROOT:-${TMPDIR:-/tmp}/idphoto-appstore-upload/${RUN_ID}}"
ARCHIVE_PATH="${OUTPUT_ROOT}/${SCHEME}.xcarchive"
EXPORT_PATH="${OUTPUT_ROOT}/export"
EXPORT_OPTIONS_PLIST="${OUTPUT_ROOT}/ExportOptions.plist"

usage() {
  cat <<'EOF'
Usage:
  Scripts/ReleaseToAppStore.sh

What it does:
  1. Reads the current MARKETING_VERSION from the Xcode project.
  2. Increases the minor version by 0.1, for example 1.1 -> 1.2.
  3. Sets CURRENT_PROJECT_VERSION to today's date, for example 20260628.
  4. Archives the Release build for generic iOS device.
  5. Uploads the archive to App Store Connect.

Optional environment variables:
  SCHEME=VisaPhotoMaker
  CONFIGURATION=Release
  TEAM_ID=MAH98XTZBR
  BUILD_NUMBER=20260628
  OUTPUT_ROOT=/tmp/idphoto-appstore-upload/manual

Optional App Store Connect API key authentication:
  ASC_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8
  ASC_KEY_ID=XXXXXXXXXX
  ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

If ASC_* variables are not set, xcodebuild uses the Apple account configured in Xcode.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

current_version() {
  awk -F'= ' '/MARKETING_VERSION = / {
    gsub(/;/, "", $2)
    print $2
    exit
  }' "$PROJECT_FILE"
}

next_minor_version() {
  awk -v version="$1" 'BEGIN {
    n = split(version, parts, ".")
    major = parts[1] + 0
    minor = n >= 2 ? parts[2] + 0 : 0
    printf "%d.%d\n", major, minor + 1
  }'
}

update_project_versions() {
  local next_version="$1"
  local build_number="$2"

  perl -0pi -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${next_version};/g" "$PROJECT_FILE"
  perl -0pi -e "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${build_number};/g" "$PROJECT_FILE"
}

write_export_options() {
  mkdir -p "$OUTPUT_ROOT" "$EXPORT_PATH"
  /usr/libexec/PlistBuddy -c "Clear dict" "$EXPORT_OPTIONS_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :method string app-store-connect" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :destination string upload" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :teamID string ${TEAM_ID}" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :signingStyle string automatic" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :manageAppVersionAndBuildNumber bool false" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :uploadSymbols bool true" "$EXPORT_OPTIONS_PLIST"
  /usr/libexec/PlistBuddy -c "Add :stripSwiftSymbols bool true" "$EXPORT_OPTIONS_PLIST"
}

xcode_auth_args=()
configure_auth_args() {
  if [[ -n "${ASC_KEY_PATH:-}" || -n "${ASC_KEY_ID:-}" || -n "${ASC_ISSUER_ID:-}" ]]; then
    if [[ -z "${ASC_KEY_PATH:-}" || -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
      echo "ASC_KEY_PATH, ASC_KEY_ID, and ASC_ISSUER_ID must be set together." >&2
      exit 1
    fi
    xcode_auth_args=(
      -authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    )
  fi
}

main() {
  require_command awk
  require_command perl
  require_command xcodebuild

  if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "Cannot find Xcode project file: $PROJECT_FILE" >&2
    exit 1
  fi

  local old_version
  old_version="$(current_version)"
  if [[ -z "$old_version" ]]; then
    echo "Cannot read MARKETING_VERSION from $PROJECT_FILE" >&2
    exit 1
  fi

  local new_version
  new_version="$(next_minor_version "$old_version")"

  echo "Project: $PROJECT_PATH"
  echo "Scheme: $SCHEME"
  echo "Configuration: $CONFIGURATION"
  echo "Version: $old_version -> $new_version"
  echo "Build: $BUILD_NUMBER"
  echo "Output: $OUTPUT_ROOT"

  update_project_versions "$new_version" "$BUILD_NUMBER"
  write_export_options
  configure_auth_args

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    "${xcode_auth_args[@]}" \
    clean archive

  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates \
    "${xcode_auth_args[@]}"

  echo "Uploaded to App Store Connect."
  echo "Archive: $ARCHIVE_PATH"
}

main "$@"
