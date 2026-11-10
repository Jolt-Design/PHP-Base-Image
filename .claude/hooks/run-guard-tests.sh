#!/usr/bin/env bash
# Usage: run-guard-tests.sh <hook> <cases-file>   (cases: "<want>|<command>" per line)
hook="$1"; cases="$2"; extra="${3:-/dev/null}"
pass=0; fail=0
while IFS= read -r line; do
  want="${line%%|*}"; c="${line#*|}"
  out=$(jq -n --arg c "$c" '{tool_input:{command:$c}}' | "$hook"); rc=$?
  got=$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null); got=${got:-none}
  if [[ $got == "$want" && $rc == 0 ]]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL want=$want got=$got rc=$rc :: $c"; fi
done < <(cat "$cases" "$extra" 2>/dev/null)
echo "pass=$pass fail=$fail"
