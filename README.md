# nim-eth3-scenarios

Deterministic test vector snapshots for Nim Eth3 development.

This repository acts as a CI hub:
- pin `vendor/leanspec` to a specific commit,
- generate both `test` and `prod` vectors from LeanSpec (`uv run fill`),
- package vectors into release tarballs,
- publish those tarballs via GitHub Releases.

## Purpose

* Provide reproducible, versioned test snapshots
* Pin artifacts to a specific LeanSpec commit
* Support CI and cross-client testing

## Download helper

Use `download_test_vectors.sh` to fetch and unpack one or more release versions:

```bash
./download_test_vectors.sh v0.1.0
LEANSPEC_TEST_VECTOR_VERSIONS=v0.1.0,v0.1.1 ./download_test_vectors.sh
```
For each version, the script writes:
- `tests-<version>/test`
- `tests-<version>/prod`
