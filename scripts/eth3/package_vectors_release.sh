#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION=""
OUT_DIR="${ROOT_DIR}/dist"
EXPORT_ENV_FILE=""
TEST_VECTORS_DIR="${ROOT_DIR}/lean-spec-vectors/test"
PROD_VECTORS_DIR="${ROOT_DIR}/lean-spec-vectors/prod"

checksum_line() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1"
  else
    shasum -a 256 "$1"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --env-file)
      EXPORT_ENV_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${VERSION}" ]]; then
  echo "Missing required --version argument" >&2
  exit 1
fi

if ! [[ "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version '${VERSION}'. Expected vX.Y.Z style tag." >&2
  exit 1
fi

if [[ ! -d "${TEST_VECTORS_DIR}" ]] || [[ -z "$(find "${TEST_VECTORS_DIR}" -type f -print -quit)" ]]; then
  echo "Test vectors directory missing or empty: ${TEST_VECTORS_DIR}" >&2
  exit 1
fi

if [[ ! -d "${PROD_VECTORS_DIR}" ]] || [[ -z "$(find "${PROD_VECTORS_DIR}" -type f -print -quit)" ]]; then
  echo "Prod vectors directory missing or empty: ${PROD_VECTORS_DIR}" >&2
  exit 1
fi

if [[ "${OUT_DIR}" == "/" || -z "${OUT_DIR}" ]]; then
  echo "Refusing to write to unsafe output directory: ${OUT_DIR}" >&2
  exit 1
fi

ARCHIVE_STEM="eth3-lean-spec-vectors-${VERSION}"
STAGING_PARENT="${OUT_DIR}/.staging"
STAGING_DIR="${STAGING_PARENT}/${ARCHIVE_STEM}"
TARBALL_PATH="${OUT_DIR}/${ARCHIVE_STEM}.tar.gz"
TARBALL_SHA256_PATH="${TARBALL_PATH}.sha256"

rm -rf "${STAGING_DIR}"
mkdir -p "${OUT_DIR}"

cp -a "${TEST_VECTORS_DIR}" "${STAGING_DIR}/test"
cp -a "${PROD_VECTORS_DIR}" "${STAGING_DIR}/prod"

rm -f "${TARBALL_PATH}" "${TARBALL_SHA256_PATH}"
tar -C "${STAGING_DIR}" -czf "${TARBALL_PATH}" test prod
(
  cd "${OUT_DIR}"
  checksum_line "$(basename -- "${TARBALL_PATH}")" > "$(basename -- "${TARBALL_SHA256_PATH}")"
)

if [[ -n "${EXPORT_ENV_FILE}" ]]; then
  mkdir -p "$(dirname -- "${EXPORT_ENV_FILE}")"
  {
    printf 'VECTOR_TARBALL=%q\n' "${TARBALL_PATH}"
    printf 'VECTOR_TARBALL_SHA256=%q\n' "${TARBALL_SHA256_PATH}"
  } > "${EXPORT_ENV_FILE}"
fi
