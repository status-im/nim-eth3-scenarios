# nim-eth3-scenarios

Deterministic test vector snapshots for Nim Eth3 development.

This repository acts as a CI hub:
- pin `vendor/leanspec` to a specific commit,
- generate vectors from LeanSpec (`uv run fill`),
- package vectors into release tarballs,
- publish those tarballs via GitHub Releases.

## Purpose

* Provide reproducible, versioned test snapshots
* Pin artifacts to a specific LeanSpec commit
* Support CI and cross-client testing
