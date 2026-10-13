#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MODE=${1:-all}
case "$MODE" in all|demo) ;; *) echo "usage: $0 [all|demo]" >&2; exit 2 ;; esac
BUILD=${BUILD:-"$ROOT/build/ghdl/$MODE"}
if [ -n "${GHDL:-}" ]; then
  :
elif command -v ghdl >/dev/null 2>&1; then
  GHDL=ghdl
elif [ -x "$ROOT/build/tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl" ]; then
  GHDL="$ROOT/build/tools/ghdl/ghdl-llvm-6.0.0-macos14-aarch64/bin/ghdl"
else
  GHDL=ghdl
fi

if ! command -v "$GHDL" >/dev/null 2>&1; then
  echo "error: GHDL not found (set GHDL=/path/to/ghdl)" >&2
  exit 127
fi
mkdir -p "$BUILD"
cd "$ROOT"
rm -f "$BUILD/work-obj93.cf"

while IFS= read -r source; do
  case "$source" in ''|'#'*) continue ;; esac
  if [ ! -f "$source" ]; then
    echo "error: required source missing: $source" >&2
    exit 2
  fi
  "$GHDL" -a --std=93 --workdir="$BUILD" "$ROOT/$source"
done < sim/sources.txt

if [ "$MODE" = demo ] && [ ! -f "$ROOT/sim/tb_demo.vhd" ]; then
  echo "error: demo testbench is not present in this checkout" >&2
  exit 2
fi

if [ "$MODE" = demo ] || [ -f "$ROOT/sim/tb_demo.vhd" ]; then
  for source in rtl/demo_cpu.vhd rtl/demo_memory.vhd rtl/demo_monitor.vhd rtl/demo_top.vhd; do
    if [ ! -f "$ROOT/$source" ]; then
      echo "error: demo source missing: $source" >&2
      exit 2
    fi
    "$GHDL" -a --std=93 --workdir="$BUILD" "$ROOT/$source"
  done
  "$GHDL" -a --std=93 --workdir="$BUILD" "$ROOT/sim/tb_demo.vhd"
fi

if [ "$MODE" = all ]; then
  for source in sim/cache_tb_pkg.vhd sim/main_memory_model.vhd sim/tb_cache_ram.vhd sim/tb_cache.vhd; do
    "$GHDL" -a --std=93 --workdir="$BUILD" "$ROOT/$source"
  done
fi

run_tb() {
  unit=$1
  stop=$2
  flags=${3:-}
  generics=${4:-}
  name=${5:-$unit}
  log="$BUILD/$name.log"
  # shellcheck disable=SC2086
  "$GHDL" -e --std=93 $flags --workdir="$BUILD" "$unit"
  # shellcheck disable=SC2086
  if [ "$unit" = tb_demo ] && [ "${WAVE:-0}" = 1 ]; then
    # shellcheck disable=SC2086
    if ! "$GHDL" -r --std=93 $flags $generics --workdir="$BUILD" "$unit" --assert-level=error --stop-time="$stop" --wave="$BUILD/$name.ghw" >"$log" 2>&1; then
      cat "$log"
      exit 1
    fi
  elif ! "$GHDL" -r --std=93 $flags $generics --workdir="$BUILD" "$unit" --assert-level=error --stop-time="$stop" >"$log" 2>&1; then
    cat "$log"
    exit 1
  fi
  cat "$log"
  if ! grep -q "PASS $unit" "$log"; then
    echo "error: $unit stopped without its PASS report" >&2
    exit 1
  fi
}

cd "$BUILD"

if [ "$MODE" = demo ]; then
  run_tb tb_demo 9ms
  run_tb tb_demo 9ms "" "-gEXTENDED_DEMO=false" tb_demo_course
  echo "PASS run_tests.sh demo"
  exit 0
fi

run_tb tb_cache_ram 900ns
run_tb tb_cache 9ms
run_tb tb_cache 9ms "" "-gREGISTERED_MEMORY=true" tb_cache_registered

if [ -f "$ROOT/reference/local/course_cpu.vhd" ]; then
  "$GHDL" -a --std=93 -fexplicit -fsynopsys --workdir="$BUILD" "$ROOT/reference/local/course_cpu.vhd"
  "$GHDL" -a --std=93 -fexplicit -fsynopsys --workdir="$BUILD" "$ROOT/sim/tb_course_cpu.vhd"
  run_tb tb_course_cpu 9ms "-fexplicit -fsynopsys"
else
  echo "SKIP tb_course_cpu: ignored reference/local/course_cpu.vhd is absent"
fi

if [ -f "$ROOT/sim/tb_demo.vhd" ]; then
  run_tb tb_demo 9ms
  run_tb tb_demo 9ms "" "-gEXTENDED_DEMO=false" tb_demo_course
else
  echo "SKIP tb_demo: public demo CPU testbench not present"
fi

echo "PASS run_tests.sh"
