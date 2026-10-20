#!/bin/sh
# Esegue tutti i test di Tabby sul "Mac simulato" (finto Hammerspoon in Lua).
# Requisiti: python3 + lupa  →  pip3 install lupa
cd "$(dirname "$0")"
fail=0
for t in test_*.py; do
  printf '\n### %s\n' "$t"
  out=$(python3 "$t" 2>&1); code=$?
  echo "$out" | tail -25
  if [ $code -ne 0 ] || ! echo "$out" | grep -q "TUTTO OK"; then fail=1; echo ">>> FALLITO: $t"; fi
done
[ $fail -eq 0 ] && printf '\nTUTTI I TEST OK\n' || printf '\nALCUNI TEST FALLITI\n'
exit $fail
