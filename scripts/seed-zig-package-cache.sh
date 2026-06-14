#!/usr/bin/env bash
set -euo pipefail

# Work around Zig 0.16 failing to fetch zip package dependencies into an empty
# package cache. zig-sqlite depends on SQLite's amalgamation zip, so seed the
# exact package archive Zig expects before running `zig build` in CI.

hash="N-V-__8AAH-mpwB7g3MnqYU-ooUBF1t99RP27dZ9addtMVXD"
url="https://www.sqlite.org/2025/sqlite-amalgamation-3490200.zip"

cache_root="${ZIG_GLOBAL_CACHE_DIR:-${HOME}/.cache/zig}"
cache_dir="${cache_root}/p"
archive="${cache_dir}/${hash}.tar.gz"

if [[ -f "${archive}" ]]; then
  exit 0
fi

mkdir -p "${cache_dir}"

python3 - "${url}" "${hash}" "${archive}" <<'PY'
import pathlib
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

url = sys.argv[1]
package_hash = sys.argv[2]
archive = pathlib.Path(sys.argv[3])

with tempfile.TemporaryDirectory() as tmp_dir_name:
    tmp_dir = pathlib.Path(tmp_dir_name)
    zip_path = tmp_dir / "sqlite.zip"
    urllib.request.urlretrieve(url, zip_path)

    extract_dir = tmp_dir / "extract"
    with zipfile.ZipFile(zip_path) as zip_file:
        zip_file.extractall(extract_dir)

    source_dir = extract_dir / "sqlite-amalgamation-3490200"
    with tarfile.open(archive, "w:gz") as tar:
        for path in sorted(source_dir.iterdir()):
            tar.add(path, arcname=f"{package_hash}/{path.name}")
PY
