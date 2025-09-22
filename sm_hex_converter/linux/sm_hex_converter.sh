#!/usr/bin/env bash
set -euo pipefail
print_help() {
  cat >&2 <<'EOF'
Usage:
  sm_hex_converter [options...] "INPUT"
  sm_hex_converter [options...] -filelist "PATH/TO/LIST.TXT"

Modes (case-insensitive; combine, order preserved):
  -tomems | -m       -> "AA BB ..." (uppercase). 2A -> "?", and input "?" stays "?".
  -tohex  | -x       -> "AA BB ..." (uppercase). "?" -> "2A".
  -togamedata | -g   -> "\xAA\xBB\xCC" (uppercase). "?" -> "\x2A".

Extra:
  -prepverify | -pverify | -pv  (aliases; also accept -prepareverify)
      When used with -g, also prints a ready, quoted line:
      "verify:" "\xAA\xBB..."   (prepped for verify; copy/paste as-is)

Strict input (no auto-fix):
  • Space-hex with optional '?': ^([0-9A-Fa-f]{2}|\?)( ([0-9A-Fa-f]{2}|\?))*$
  • Gamedata bytes:              ^(\\x[0-9A-Fa-f]{2})+$   (no '?' allowed)

-filelist "PATH":
  Lines starting with '#' or leading whitespace are ignored.
  One header per input line; then all requested conversions for that line.
EOF
}
is_space_hex_q()  { [[ "$1" =~ ^([0-9A-Fa-f]{2}|\?)(\ ([0-9A-Fa-f]{2}|\?))*$ ]]; }
is_gamedata_hex() { [[ "$1" =~ ^(\\x[0-9A-Fa-f]{2})+$ ]]; }
parse_strict_bytes() {
  local line="$1"
  if is_space_hex_q "$line"; then
    local out=() t
    while IFS=' ' read -r -a toks; do
      for t in "${toks[@]}"; do
        if [[ "$t" == "?" ]]; then out+=("?"); else out+=("${t^^}"); fi
      done
    done <<< "$line"
    printf '%s\n' "${out[*]}"
    return 0
  elif is_gamedata_hex "$line"; then
    local spaced="${line//\\x/ }"; spaced="${spaced# }"
    printf '%s\n' "${spaced^^}"
    return 0
  else
    return 1
  fi
}
emit_tomems() {
  local -a b=("$@") out=() v
  for v in "${b[@]}"; do
    if [[ "$v" == "?" || "$v" == "2A" ]]; then out+=("?"); else out+=("$v"); fi
  done
  printf 'tomems conversion (Used to memory search in for example Ghidra or IDA):\n'
  printf '%s\n' "$(printf '%s ' "${out[@]}" | sed 's/ $//')"
}
emit_tohex() {
  local -a b=("$@") out=() v
  for v in "${b[@]}"; do
    if [[ "$v" == "?" ]]; then out+=("2A"); else out+=("$v"); fi
  done
  printf 'tohex conversion (Raw hex output, keeps 2A bytes):\n'
  printf '%s\n' "$(printf '%s ' "${out[@]}" | sed 's/ $//')"
}
emit_togamedata() {
  local -a b=("$@") v out=""
  for v in "${b[@]}"; do
    if [[ "$v" == "?" ]]; then out+="\\x2A"; else out+="\\x${v}"; fi
  done
  printf 'togamedata conversion (Used for SourceMod Address stuff and SourceScramble):\n'
  printf '%s\n' "$out"
  if [[ $PREPVERIFY -eq 1 ]]; then
    printf 'prepped for verify — copy the next line exactly:\n'
    printf '"verify:" "%s"\n' "$out"
  fi
}
for a in "$@"; do al="${a,,}"; [[ "$al" == "-h" || "$al" == "-help" ]] && { print_help; exit 0; }; done
[[ $# -lt 2 ]] && { echo "Error: no conversion mode given." >&2; print_help; exit 1; }
filelist=""; PREPVERIFY=0
declare -a modes=(); args=("$@")
for ((i=0;i<${#args[@]};i++)); do
  al="${args[$i],,}"
  case "$al" in
    -filelist)
      (( i+1<${#args[@]} )) || { echo "Error: -filelist requires a path." >&2; exit 1; }
      filelist="${args[$((i+1))]}"; ((i++));;
    -tomems|-m)      modes+=("-tomems");;
    -tohex|-x)       modes+=("-tohex");;
    -togamedata|-g)  modes+=("-togamedata");;
    -prepverify|-pverify|-pv|-prepareverify) PREPVERIFY=1;;
  esac
done
[[ ${#modes[@]} -eq 0 ]] && { echo "Error: no conversion mode given." >&2; print_help; exit 1; }
if [[ -n "$filelist" ]]; then
  [[ -f "$filelist" ]] || { echo "Error: file not found: $filelist" >&2; exit 1; }
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}; lineno=$((lineno+1))
    if [[ "$line" =~ ^[[:space:]] || "$line" =~ ^# ]]; then continue; fi
    [[ -z "$line" ]] && continue
    printf '[file "%s", line %d]\n' "$filelist" "$lineno"
    parsed="$(parse_strict_bytes "$line" || true)"
    if [[ -z "$parsed" ]]; then
      echo "REJECTED: invalid format. Expected 'AA 00 CC' with optional '?' bytes, or '\\xAA\\x00\\xCC' (no '?')."
      continue
    fi
    read -r -a BYTES <<< "$parsed"
    for m in "${modes[@]}"; do
      case "$m" in
        -tomems)     emit_tomems "${BYTES[@]}" ;;
        -tohex)      emit_tohex "${BYTES[@]}" ;;
        -togamedata) emit_togamedata "${BYTES[@]}" ;;
      esac
    done
  done < "$filelist"
else
  input="${@: -1}"
  parsed="$(parse_strict_bytes "$input" || true)"
  if [[ -z "$parsed" ]]; then
    echo "REJECTED: invalid format. Expected 'AA 00 CC' with optional '?' bytes, or '\\xAA\\x00\\xCC' (no '?')." >&2
    exit 2
  fi
  read -r -a BYTES <<< "$parsed"
  for m in "${modes[@]}"; do
    case "$m" in
      -tomems)     emit_tomems "${BYTES[@]}" ;;
      -tohex)      emit_tohex "${BYTES[@]}" ;;
      -togamedata) emit_togamedata "${BYTES[@]}" ;;
    esac
  done
fi
