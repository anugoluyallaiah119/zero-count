#!/usr/bin/env bash
# Zero Count V2 — game-engine CI gate.
# Compiles the engine + tests, then runs every suite. Any failure aborts (exit 1).
#
# Usage:
#   ./run-tests.sh                 # unit + integration suites, 10k-match sim gate
#   ./run-tests.sh --quick         # unit suites + 500-match sim smoke (fast local loop)
#   JAVA_HOME=/path/to/jdk17 ./run-tests.sh
set -euo pipefail
cd "$(dirname "$0")"

JAVA_HOME="${JAVA_HOME:-$(dirname "$(readlink -f "$(command -v java)")")/..}"
JAVAC="$JAVA_HOME/bin/javac"
JAVA="$JAVA_HOME/bin/java"
[ -x "$JAVAC" ] || { echo "ERROR: javac not found (set JAVA_HOME to a JDK 17+)"; exit 1; }

SIM_MATCHES=2000   # per configuration; 5 configs => 10,000 matches
[ "${1:-}" = "--quick" ] && SIM_MATCHES=100

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

echo "== compile (UTF-8, -Xlint) =="
find src/main/java src/test/java -name '*.java' > "$OUT/sources.txt"
"$JAVAC" -encoding UTF-8 -Xlint:all -d "$OUT/classes" @"$OUT/sources.txt"

run_suite() {
  echo "== $1 =="
  "$JAVA" -cp "$OUT/classes" "com.zerocount.engine.$1" ${2:-}
}

run_suite E1_1_ModelTest
run_suite E1_2_ScoringTest
run_suite E1_3_SessionTest
run_suite E1_4_AiTest
run_suite E1_5_SimulationTest "$SIM_MATCHES"

echo "== ALL GATES PASSED =="
