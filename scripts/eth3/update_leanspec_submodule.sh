#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_DIR="${ROOT_DIR}/vendor/leanspec"
ENV_FILE="${ROOT_DIR}/.tmp/leanspec.env"
REF=""

# Keep the vendored leanSpec submodule initialized automatically.
git -C "${ROOT_DIR}" submodule update --init --recursive vendor/leanspec

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      REF="$2"
      shift 2
      ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${REF}" ]]; then
  echo "Missing required --ref argument" >&2
  exit 1
fi

git -C "${REPO_DIR}" fetch --tags origin
git -C "${REPO_DIR}" checkout "${REF}"

LEANSPEC_SHA="$(git -C "${REPO_DIR}" rev-parse HEAD)"
LEANSPEC_SHORT_SHA="$(git -C "${REPO_DIR}" rev-parse --short=12 HEAD)"
LEANSPEC_REMOTE="$(git -C "${REPO_DIR}" remote get-url origin)"
LEANSPEC_COMMIT_DATE_UTC="$(git -C "${REPO_DIR}" show -s --format=%cI HEAD)"

mkdir -p "$(dirname -- "${ENV_FILE}")"
{
  printf 'LEANSPEC_REF_REQUESTED=%q\n' "${REF}"
  printf 'LEANSPEC_SHA=%q\n' "${LEANSPEC_SHA}"
  printf 'LEANSPEC_SHORT_SHA=%q\n' "${LEANSPEC_SHORT_SHA}"
  printf 'LEANSPEC_REMOTE=%q\n' "${LEANSPEC_REMOTE}"
  printf 'LEANSPEC_COMMIT_DATE_UTC=%q\n' "${LEANSPEC_COMMIT_DATE_UTC}"
} > "${ENV_FILE}"
