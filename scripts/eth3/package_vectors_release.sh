#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION=""
VECTORS_DIR="${ROOT_DIR}/lean-spec-vectors"
OUT_DIR="${ROOT_DIR}/dist"
LEANSPEC_ENV_FILE="${ROOT_DIR}/.tmp/leanspec.env"
FORK="Devnet"
SCHEME=""
EXPORT_ENV_FILE=""

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "${s}"
}

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
    --vectors-dir)
      VECTORS_DIR="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --leanspec-env-file)
      LEANSPEC_ENV_FILE="$2"
      shift 2
      ;;
    --fork)
      FORK="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
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

if [[ ! -d "${VECTORS_DIR}" ]] || [[ -z "$(find "${VECTORS_DIR}" -type f -print -quit)" ]]; then
  echo "Vectors directory missing or empty: ${VECTORS_DIR}" >&2
  exit 1
fi

if [[ "${OUT_DIR}" == "/" || -z "${OUT_DIR}" ]]; then
  echo "Refusing to write to unsafe output directory: ${OUT_DIR}" >&2
  exit 1
fi

if [[ -f "${LEANSPEC_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${LEANSPEC_ENV_FILE}"
fi
LEANSPEC_REF_REQUESTED="${LEANSPEC_REF_REQUESTED:-unknown}"
LEANSPEC_SHA="${LEANSPEC_SHA:-}"
LEANSPEC_SHORT_SHA="${LEANSPEC_SHORT_SHA:-${LEANSPEC_SHA:0:12}}"
LEANSPEC_REMOTE="${LEANSPEC_REMOTE:-}"
LEANSPEC_COMMIT_DATE_UTC="${LEANSPEC_COMMIT_DATE_UTC:-}"

GENERATOR_REPO_SHA="$(git -C "${ROOT_DIR}" rev-parse --verify HEAD 2>/dev/null || echo unknown)"
GENERATOR_REPO_REMOTE="$(git -C "${ROOT_DIR}" remote get-url origin 2>/dev/null || true)"
GENERATED_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

ARCHIVE_STEM="eth3-lean-spec-vectors-${VERSION}"
STAGING_PARENT="${OUT_DIR}/.staging"
STAGING_DIR="${STAGING_PARENT}/${ARCHIVE_STEM}"
METADATA_DIR="${STAGING_DIR}/metadata"
METADATA_JSON="${METADATA_DIR}/leanspec.json"
MANIFEST_FILENAME="MANIFEST.sha256"
TARBALL_PATH="${OUT_DIR}/${ARCHIVE_STEM}.tar.gz"
TARBALL_SHA256_PATH="${TARBALL_PATH}.sha256"
METADATA_ASSET_PATH="${OUT_DIR}/metadata-leanspec-${VERSION}.json"

rm -rf "${STAGING_DIR}"
mkdir -p "${METADATA_DIR}" "${OUT_DIR}"

cp -a "${VECTORS_DIR}" "${STAGING_DIR}/lean-spec-vectors"

cat > "${METADATA_JSON}" <<EOF
{
  "version": "$(json_escape "${VERSION}")",
  "leanspecRefRequested": "$(json_escape "${LEANSPEC_REF_REQUESTED}")",
  "leanspecSha": "$(json_escape "${LEANSPEC_SHA}")",
  "leanspecShortSha": "$(json_escape "${LEANSPEC_SHORT_SHA}")",
  "leanspecRemote": "$(json_escape "${LEANSPEC_REMOTE}")",
  "leanspecCommitDateUtc": "$(json_escape "${LEANSPEC_COMMIT_DATE_UTC}")",
  "fork": "$(json_escape "${FORK}")",
  "scheme": "$(json_escape "${SCHEME}")",
  "generatedAtUtc": "$(json_escape "${GENERATED_AT_UTC}")",
  "generatorRepoSha": "$(json_escape "${GENERATOR_REPO_SHA}")",
  "generatorRepoRemote": "$(json_escape "${GENERATOR_REPO_REMOTE}")"
}
EOF

(
  cd "${STAGING_DIR}"
  find lean-spec-vectors metadata -type f ! -name "${MANIFEST_FILENAME}" -print0 \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' file; do
        checksum_line "${file}"
      done > "metadata/${MANIFEST_FILENAME}"
)

rm -f "${TARBALL_PATH}" "${TARBALL_SHA256_PATH}" "${METADATA_ASSET_PATH}"
tar -C "${STAGING_PARENT}" -czf "${TARBALL_PATH}" "${ARCHIVE_STEM}"
(
  cd "${OUT_DIR}"
  checksum_line "$(basename -- "${TARBALL_PATH}")" > "$(basename -- "${TARBALL_SHA256_PATH}")"
)
cp "${METADATA_JSON}" "${METADATA_ASSET_PATH}"

if [[ -n "${EXPORT_ENV_FILE}" ]]; then
  mkdir -p "$(dirname -- "${EXPORT_ENV_FILE}")"
  {
    printf 'VECTOR_TARBALL=%q\n' "${TARBALL_PATH}"
    printf 'VECTOR_TARBALL_SHA256=%q\n' "${TARBALL_SHA256_PATH}"
    printf 'VECTOR_METADATA_ASSET=%q\n' "${METADATA_ASSET_PATH}"
  } > "${EXPORT_ENV_FILE}"
fi
