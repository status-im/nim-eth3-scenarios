#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_DIR="${ROOT_DIR}/vendor/leanspec"
OUT_DIR="${ROOT_DIR}/lean-spec-vectors"
FORK="Devnet"
SCHEME=""
PYTHON_VERSION="3.12"

bootstrap_uv() {
  if command -v uv >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "uv is not installed and curl is unavailable for bootstrap" >&2
    exit 1
  fi

  echo "uv is missing; installing via https://astral.sh/uv/install.sh"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"

  if ! command -v uv >/dev/null 2>&1; then
    echo "uv bootstrap completed but 'uv' is still unavailable in PATH" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir)
      REPO_DIR="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
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
    --python-version)
      PYTHON_VERSION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Only initialize the default vendored repo when it is missing or not a git worktree.
# Do not run unconditional `submodule update` here because callers may have already
# checked out a specific leanSpec commit for this run.
if [[ "${REPO_DIR}" == "${ROOT_DIR}/vendor/leanspec" ]]; then
  if ! git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "${ROOT_DIR}" submodule update --init --recursive vendor/leanspec
  fi
fi

if [[ ! -d "${REPO_DIR}" ]]; then
  echo "leanSpec repo directory not found: ${REPO_DIR}" >&2
  exit 1
fi

if [[ ! -f "${REPO_DIR}/pyproject.toml" ]]; then
  echo "Expected pyproject.toml not found in leanSpec repo: ${REPO_DIR}" >&2
  exit 1
fi

if [[ "${OUT_DIR}" == "/" || -z "${OUT_DIR}" ]]; then
  echo "Refusing to write to unsafe output directory: ${OUT_DIR}" >&2
  exit 1
fi

bootstrap_uv

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

OUT_DIR_ABS="$(cd -- "$(dirname -- "${OUT_DIR}")" && pwd)/$(basename -- "${OUT_DIR}")"

pushd "${REPO_DIR}" >/dev/null
uv python install "${PYTHON_VERSION}"
uv sync --no-progress

FILL_CMD=(
  uv run fill
  --fork="${FORK}"
  --clean
  -n auto
  --output="${OUT_DIR_ABS}"
)
if [[ -n "${SCHEME}" ]]; then
  FILL_CMD+=(--scheme="${SCHEME}")
fi

"${FILL_CMD[@]}"
popd >/dev/null

if [[ -z "$(find "${OUT_DIR_ABS}" -type f -print -quit)" ]]; then
  echo "Vector generation completed but output directory is empty: ${OUT_DIR_ABS}" >&2
  exit 1
fi

echo "Generated vectors in ${OUT_DIR_ABS} from ${REPO_DIR}"
