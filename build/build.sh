#!/bin/sh
# Сборка игры: build/build.sh [web|windows|all]. Владелец: A.
# Нужны Godot 4.7.2 в PATH (или переменная GODOT) и шаблоны экспорта этой версии.
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TARGET="${1:-all}"

# Первый импорт создаёт .godot/ с кэшем ресурсов; без него экспорт пропускает картинки.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

if [ "$TARGET" = "web" ] || [ "$TARGET" = "all" ]; then
	rm -rf build/web && mkdir -p build/web
	"$GODOT" --headless --path . --export-release Web build/web/index.html
	test -s build/web/index.wasm && test -s build/web/index.pck
	echo "Web: build/web/index.html"
fi

if [ "$TARGET" = "windows" ] || [ "$TARGET" = "all" ]; then
	rm -rf build/windows && mkdir -p build/windows
	"$GODOT" --headless --path . --export-release Windows build/windows/DALA_WORKS.exe
	test -s build/windows/DALA_WORKS.exe
	rm -f build/dala-works-win64.zip
	(cd build/windows && zip -q9 ../dala-works-win64.zip DALA_WORKS.exe)
	echo "Windows: build/dala-works-win64.zip"
fi
