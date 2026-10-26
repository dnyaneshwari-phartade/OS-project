#!/bin/bash

make >/dev/null 2>&1 || { echo "BUILD FAILED"; exit 1; }

OUT=$(mktemp)
S=${SLOW:-1}     # speed factor: run "SLOW=2 ./run_tests.sh" on a slow machine

nap() { sleep $(( $1 * S )); }

{
  nap 10
  printf 'loop > out1.txt &\n';   nap 4
  printf 'jobs\n';                nap 4
  printf 'kill %%1\n';            nap 4
  printf 'echo MARK_A\n';         nap 3
  printf 'jobs\n';                nap 4
  printf 'echo MARK_B\n';         nap 3
  printf 'loop > out2.txt\n';     nap 6
  printf '\x1a';                  nap 4      # Ctrl-Z
  printf 'jobs\n';                nap 4
  printf 'bg %%1\n';              nap 4
  printf 'jobs\n';                nap 4
  printf 'fg %%1\n';              nap 4
  printf '\x03';                  nap 4      # Ctrl-C
  printf 'echo MARK_C\n';         nap 3
  printf 'jobs\n';                nap 4
  printf 'echo MARK_D\n';         nap 3
  printf 'ls | wc\n';             nap 4
  printf 'jobtest\n';             nap 20
  printf 'echo ALLDONE\n';        nap 4
  printf '\x01x';                 nap 2      # Ctrl-A X quits QEMU
} | make qemu-nox > "$OUT" 2>&1

pkill -f qemu-system-i386 2>/dev/null
tr -d '\r' < "$OUT" > test_log.txt
LOG=test_log.txt

PASS=0
FAIL=0
t() {
  local name="$1"; shift
  if "$@"; then echo "PASSED: $name"; PASS=$((PASS+1))
  else          echo "FAILED: $name"; FAIL=$((FAIL+1)); fi
}

has_re() { grep -qE -- "$1" "$LOG"; }
notbetween() {
  grep -qF "$1" "$LOG" && grep -qF "$2" "$LOG" || return 1
  ! sed -n "/$1/,/$2/p" "$LOG" | grep -qE -- "$3"
}

t "xv6 booted to the shell prompt"            has_re '\$ '
t "loop & starts a background job"            has_re '\[1\] [0-9]+'
t "jobs shows a Running background job"       has_re 'Running +loop'
t "kill %1 removes the job (Done reported)"   has_re 'Done +loop'
t "jobs is empty after kill %1"               notbetween MARK_A MARK_B 'Running|Stopped'
t "Ctrl-Z stops the foreground job"           has_re 'Stopped +loop'
t "jobs shows the Stopped job"                has_re '\[1\] +Stopped +loop'
t "bg %1 resumes the job in the background"   has_re '\[1\] +loop > out2.txt +&'
t "jobs shows Running after bg"               has_re '\[1\] +Running +loop > out2.txt'
t "fg %1 brings the job to the foreground"    has_re '^loop > out2.txt'
t "Ctrl-C kills the foreground job"           notbetween MARK_C MARK_D 'Running|Stopped'
t "shell still works after all of this"       has_re 'ALLDONE'

if grep -q 'RESULT:' "$LOG"; then
  grep -E '^(PASSED|FAILED):' "$LOG" | sed 's/^/[jobtest] /'
  JF=$(grep -c '^FAILED:' "$LOG")
  JP=$(grep -c '^PASSED:' "$LOG")
  PASS=$((PASS+JP)); FAIL=$((FAIL+JF))
else
  echo "FAILED: jobtest did not finish"; FAIL=$((FAIL+1))
fi

echo "----------------------------------"
echo "TOTAL: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]