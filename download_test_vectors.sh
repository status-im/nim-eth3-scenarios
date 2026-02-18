#!/usr/bin/env bash

# Copyright (c) 2026 Status Research & Development GmbH.
# Licensed under Apache-2.0 or MIT at your option.

set -Eeuo pipefail

if [[ -n "${CONSENSUS_TEST_VECTOR_VERSIONS:-}" ]]; then
  IFS=',' read -r -a VERSIONS <<< "${CONSENSUS_TEST_VECTOR_VERSIONS}"
else
  VERSIONS=("$@")
fi

if [[ "${#VERSIONS[@]}" -eq 0 ]]; then
  echo "Set CONSENSUS_TEST_VECTOR_VERSIONS or pass at least one version (for example: v1.0.0)." >&2
  exit 1
fi

VECTOR_RELEASE_REPO="${VECTOR_RELEASE_REPO:-status-im/nim-eth3-scenarios}"

if command -v sha256sum >/dev/null 2>&1; then
  CHECKSUM_BIN=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  CHECKSUM_BIN=(shasum -a 256)
else
  echo "Missing checksum tool: require sha256sum or shasum." >&2
  exit 1
fi

trap 'echo; echo "Interrupted."; exit 1' SIGINT SIGTERM

EXTRA_TAR=()
if tar --version 2>/dev/null | grep -qi 'gnu'; then
  EXTRA_TAR=(--warning=no-unknown-keyword --ignore-zeros)
fi

for version in "${VERSIONS[@]}"; do
  tarball_name="eth3-lean-spec-vectors-${version}.tar.gz"
  checksum_name="${tarball_name}.sha256"
  release_base="https://github.com/${VECTOR_RELEASE_REPO}/releases/download/${version}"
  target_dir="tarballs/${version}"
  out_dir="tests-${version}"

  mkdir -p "${target_dir}"

  curl --fail --location --show-error --retry 3 --retry-all-errors \
    --output "${target_dir}/${tarball_name}" \
    "${release_base}/${tarball_name}"

  curl --fail --location --show-error --retry 3 --retry-all-errors \
    --output "${target_dir}/${checksum_name}" \
    "${release_base}/${checksum_name}"

  (cd "${target_dir}" && "${CHECKSUM_BIN[@]}" -c "${checksum_name}")

  rm -rf "${out_dir}"
  mkdir -p "${out_dir}"
  tar -C "${out_dir}" --strip-components 1 "${EXTRA_TAR[@]}" -xzf "${target_dir}/${tarball_name}"
done

shopt -s nullglob

for tpath in tarballs/*; do
  tdir="$(basename -- "${tpath}")"
  if [[ ! " ${VERSIONS[*]} " =~ " ${tdir} " ]]; then
    rm -rf "${tpath}"
  fi
done

for tpath in tests-*; do
  tver="${tpath#tests-}"
  if [[ ! " ${VERSIONS[*]} " =~ " ${tver} " ]]; then
    rm -rf "${tpath}"
  fi
done

shopt -u nullglob

echo "Downloaded and unpacked versions: ${VERSIONS[*]}"
