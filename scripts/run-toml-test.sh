#!/usr/bin/env bash
# Run the official toml-test suite against vala-toml decoder/encoder (TOML 1.1).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TOML_TEST_VERSION="${TOML_TEST_VERSION:-v2.2.0}"
TOOLS_DIR="$ROOT/build/tools"
TOML_TEST="$TOOLS_DIR/toml-test"
DECODER="$TOOLS_DIR/vala-toml-decoder"
ENCODER="$TOOLS_DIR/vala-toml-encoder"

mkdir -p "$TOOLS_DIR"

if [[ ! -x "$TOML_TEST" ]]; then
	echo "Installing toml-test ${TOML_TEST_VERSION} into ${TOOLS_DIR} ..."
	GOBIN="$TOOLS_DIR" go install "github.com/toml-lang/toml-test/v2/cmd/toml-test@${TOML_TEST_VERSION}"
fi

if [[ ! -x "$DECODER" || ! -x "$ENCODER" ]]; then
	echo "Building vala-toml tools ..."
	meson compile -C build
fi

exec "$TOML_TEST" test \
	-toml=1.1 \
	-decoder="$DECODER" \
	-encoder="$ENCODER" \
	"$@"
