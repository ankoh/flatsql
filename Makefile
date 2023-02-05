.DEFAULT_GOAL := parser

# ---------------------------------------------------------------------------
# Config

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

UID=${shell id -u}
GID=${shell id -g}

PARSER_SOURCE_DIR="${ROOT_DIR}/packages/flatsql-parser"
PARSER_DEBUG_DIR="${PARSER_SOURCE_DIR}/build/native/Debug"
PARSER_RELEASE_DIR="${PARSER_SOURCE_DIR}/build/Release"
PARSER_RELWITHDEBINFO_DIR="${PARSER_SOURCE_DIR}/build/RelWithDebInfo"

CORES=$(shell grep -c ^processor /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu)

# ---------------------------------------------------------------------------
# Parser

.PHONY: parser
parser:
	mkdir -p ${PARSER_DEBUG_DIR}
	cmake -S ${PARSER_SOURCE_DIR} -B ${PARSER_DEBUG_DIR} \
		-GNinja \
		-DCMAKE_BUILD_TYPE=Debug \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=1
	ln -sf ${PARSER_DEBUG_DIR}/compile_commands.json ${PARSER_SOURCE_DIR}/compile_commands.json
	cmake --build ${PARSER_DEBUG_DIR}

# C++ formatting
.PHONY: clang_format
clang_format:
	python3 ./scripts/run_clang_format.py \
	--exclude ./lib/build \
	--exclude ./lib/third_party \
	-r ./lib/