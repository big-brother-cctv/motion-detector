# Changelog

## [1.8.1](https://github.com/big-brother-cctv/motion-detector/compare/v1.8.0...v1.8.1) (2026-10-19)


### Bug Fixes

* update motion configuration parameters and localhost IP in entrypoint script ([e83dad9](https://github.com/big-brother-cctv/motion-detector/commit/e83dad95dbce4c8e61b45ffa68a7defff0bfba5e))

## [1.8.0](https://github.com/big-brother-cctv/motion-detector/compare/v1.7.1...v1.8.0) (2026-10-18)


### Features

* refactor motion detector to support dynamic multi-camera configuration via API sync ([727953d](https://github.com/big-brother-cctv/motion-detector/commit/727953de64ed9a642159f8bc3f2476930564ed7b))

## [1.7.1](https://github.com/big-brother-cctv/motion-detector/compare/v1.7.0...v1.7.1) (2026-10-18)


### Bug Fixes

* copy motion.conf to tmp to prevent device busy errors with Kubernetes mounts ([2bab156](https://github.com/big-brother-cctv/motion-detector/commit/2bab156d5391f0899dabc908bd4b2205dbf9575e))

## [1.7.0](https://github.com/big-brother-cctv/motion-detector/compare/v1.6.0...v1.7.0) (2026-10-18)


### Features

* add container entrypoint for dynamic motion configuration and image cleanup ([cd9ee65](https://github.com/big-brother-cctv/motion-detector/commit/cd9ee6520e4c9019adb4d7a9fd8038fa2e67daac))

## [1.6.0](https://github.com/big-brother-cctv/motion-detector/compare/v1.5.1...v1.6.0) (2026-10-16)


### Features

* integrate motion scripts with self-hosted Big Brother API and make Discord webhooks optional ([4eaae02](https://github.com/big-brother-cctv/motion-detector/commit/4eaae02d731e0284aa0f9b9d8d76e825178774f6))

## [1.5.1](https://github.com/big-brother-cctv/motion-detector/compare/v1.5.0...v1.5.1) (2026-10-16)


### Bug Fixes

* **docker:** update base image to debian:bookworm-slim and safe apt flags ([8702e69](https://github.com/big-brother-cctv/motion-detector/commit/8702e69f8cdb70c21dc9b4c205ea8cb128ed2c67))

## [1.5.0](https://github.com/big-brother-cctv/motion-detector/compare/v1.4.0...v1.5.0) (2026-10-16)


### Features

* refactor CI workflow for syntax checks and add release-please workflow for GHCR publishing ([29f9d45](https://github.com/big-brother-cctv/motion-detector/commit/29f9d45e454a40b11f5b7dae77ad50718eb63947))
