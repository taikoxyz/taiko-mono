# Changelog

## [0.2.0](https://github.com/taikoxyz/taiko-mono/compare/blobstorage-v0.1.0...blobstorage-v0.2.0) (2024-05-14)


### Features

* **blobstorage:** add health check, change regular mux for echo, filter changes ([#16449](https://github.com/taikoxyz/taiko-mono/issues/16449)) ([ee1233d](https://github.com/taikoxyz/taiko-mono/commit/ee1233d523a24e682b9dced312d3ffafe76c1889))
* **blobstorage:** allow get_blob api to return blob data ([#16629](https://github.com/taikoxyz/taiko-mono/issues/16629)) ([2581772](https://github.com/taikoxyz/taiko-mono/commit/2581772afb6875de2a6f4d54a93a2f11be5ab2fc))
* **blobstorage:** isolating tables for no blob data duplication ([#16702](https://github.com/taikoxyz/taiko-mono/issues/16702)) ([55426ef](https://github.com/taikoxyz/taiko-mono/commit/55426ef700c3eabc693f32829525a42775909b2a))
* **blobstorage:** set initial indexing block via genesis if no blobs exist ([#16477](https://github.com/taikoxyz/taiko-mono/issues/16477)) ([9427ab4](https://github.com/taikoxyz/taiko-mono/commit/9427ab43c599f9d26637bb0d051e11f3ccdee47c))
* **eventindexer:** fix down mig + regen bindings ([#16563](https://github.com/taikoxyz/taiko-mono/issues/16563)) ([da5a039](https://github.com/taikoxyz/taiko-mono/commit/da5a03900409ded0488058068092d6d2ec9a0b26))
* **relayer:** regen bindings, make changes for stateVars, add isMessageReceived ([#16664](https://github.com/taikoxyz/taiko-mono/issues/16664)) ([66a35e2](https://github.com/taikoxyz/taiko-mono/commit/66a35e29aa3c688ac57ddd40a24b59aef45beff6))


### Bug Fixes

* **blobstorage, eventindexer, relayer:** remove username and password ([#16700](https://github.com/taikoxyz/taiko-mono/issues/16700)) ([35adb3d](https://github.com/taikoxyz/taiko-mono/commit/35adb3d7f5a79200573c1f6822586ea221a29dfa))
* **blobstorage:** blockId determination by timestamp ([#16614](https://github.com/taikoxyz/taiko-mono/issues/16614)) ([eba19c7](https://github.com/taikoxyz/taiko-mono/commit/eba19c766e419d7744b0d6307e103261e1dd3241))
* **blobstorage:** fix command instructions and missing local_docker folder in packages/blobstorage ([#16464](https://github.com/taikoxyz/taiko-mono/issues/16464)) ([a7e7f1a](https://github.com/taikoxyz/taiko-mono/commit/a7e7f1af40165cb27d8e10eab47f8f0f2ae458a1))
