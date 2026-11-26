# Body of `pi-job`. pi.nix prepends the job data it reads:
#   pi          the Pi executable
#   state_root  the `notify` state directory, one subdirectory per job
#   jobs        every enabled job
#   notify      jobs with `notify` set, as keys
#   sessions    job name to session directory, for jobs that keep sessions
# shellcheck shell=bash disable=SC2154

usage() {
  cat <<'USAGE'
Usage: pi-job [list]
       pi-job history <name>
       pi-job open <name> [run]
       pi-job show <name> [run]
       pi-job run <name>
       pi-job log <name> [journalctl options]

  list     Each job with its state, last run and next run (the default)
  history  The job's runs, newest first, numbered for open and show
  open     Open a run's session in Pi, the newest by default, and mark
           the job read
  show     Print a run's answer, the newest by default, and mark the job
           read. Rendered with glow on a terminal, plain when piped.
  run      Start the job now instead of waiting for its timer
  log      Show the job's journal, ending at the newest lines, and clear
           its failed mark. Options such as -f replace the default -e.

A job's state is `new` (an unread answer), `failed` (the last run
failed), `read`, or `-` (no answer yet). Only jobs with `notify` set
record a state or an answer. Only jobs that keep sessions have a
history, and `run` numbers count from 1, the newest.
USAGE
}

die() {
  echo "pi-job: $*" >&2
  exit 1
}

need_job() {
  local name=${1:-} job
  [[ -n $name ]] || die "name a job: ${jobs[*]}"
  for job in "${jobs[@]}"; do
    [[ $job == "$name" ]] && return 0
  done
  die "no job named '$name'. Jobs: ${jobs[*]}"
}

# Fails with a message when a command got more arguments than it takes.
at_most() {
  local max=$1 command=$2
  shift 2
  [[ $# -le $max ]] || die "too many arguments for '$command': $*. See 'pi-job --help'."
}

job_state() {
  local dir=$state_root/$1
  if [[ -z ${notify[$1]:-} ]]; then
    echo "-"
  elif [[ -e $dir/failed ]]; then
    echo failed
  elif [[ -e $dir/unread ]]; then
    echo new
  elif [[ -e $dir/answer.md ]]; then
    echo read
  else
    echo "-"
  fi
}

# systemd prints an empty value, or "n/a", for a unit that has not run or
# has no timer.
unit_time() {
  local value
  value=$(systemctl --user show "$1" -p "$2" --value 2>/dev/null || true)
  if [[ -z $value || $value == n/a ]]; then
    echo "-"
  else
    echo "$value"
  fi
}

list() {
  if [[ ${#jobs[@]} -eq 0 ]]; then
    echo "No Pi jobs are enabled."
    return
  fi
  local name
  printf '%-24s %-7s %-30s %s\n' JOB STATE "LAST RUN" "NEXT RUN"
  for name in "${jobs[@]}"; do
    printf '%-24s %-7s %-30s %s\n' "$name" "$(job_state "$name")" \
      "$(unit_time "pi-job-$name.service" ExecMainExitTimestamp)" \
      "$(unit_time "pi-job-$name.timer" NextElapseUSecRealtime)"
  done
}

need_sessions() {
  [[ -n ${sessions[$1]:-} ]] || die "'$1' does not keep sessions. Set pi.jobs.$1.notify or sessionDir."
}

# The job's session files, newest first. Session file names start with
# their creation time, so reverse sort order is newest first. Callers check
# need_sessions first: a `die` in a command or process substitution only
# ends that subshell.
session_files() {
  find "${sessions[$1]}" -name '*.jsonl' 2>/dev/null | sort -r || true
}

# Run `n` of the job, counting from 1 for the newest.
session_file() {
  local name=$1 n=${2:-1} session
  [[ $n =~ ^[1-9][0-9]*$ ]] || die "a run is a number from 'pi-job history $name', not '$n'"
  session=$(session_files "$name" | sed -n "${n}p")
  if [[ -z $session ]]; then
    if [[ $n -eq 1 ]]; then
      die "'$name' has no session yet. Run 'pi-job run $name' to make one."
    fi
    die "'$name' has no run $n. See 'pi-job history $name'."
  fi
  echo "$session"
}

# When the run started, in local time, read from the session file name,
# such as 2026-11-26T14-12-16-674Z_<id>.jsonl.
run_time() {
  local base
  base=$(basename "$1")
  if [[ $base =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2})-([0-9]{2})-([0-9]{2}) ]]; then
    date -d "${BASH_REMATCH[1]}T${BASH_REMATCH[2]}:${BASH_REMATCH[3]}:${BASH_REMATCH[4]}Z" '+%a %Y-%m-%d %H:%M'
  else
    echo "?"
  fi
}

# The job's answer: the last assistant text before a second user message,
# so questions asked later with `pi-job open` are not part of it.
session_answer() {
  jq -rs '
    [.[] | select(.type == "message") | .message] as $m
    | ([$m | to_entries[] | select(.value.role == "user") | .key][1] // ($m | length)) as $end
    | [$m[0:$end][] | select(.role == "assistant")] | last // {}
    | if (.content | type) == "string" then .content
      else [.content[]? | select(.type == "text") | .text] | join("\n")
      end
  ' "$1"
}

history() {
  local name=$1 session n=0 first
  printf '%-4s %-22s %s\n' RUN STARTED ANSWER
  while IFS= read -r session; do
    n=$((n + 1))
    # `head` closes the pipe early on a long answer, which pipefail would
    # report as a failure.
    first=$(session_answer "$session" | sed -e '/^[[:space:]]*$/d' -e 's/^[#* ]*//' -e 's/[* ]*$//' | head -n 1 || true)
    printf '%-4s %-22s %s\n' "$n" "$(run_time "$session")" "${first:0:70}"
  done < <(session_files "$name")
  [[ $n -gt 0 ]] || echo "No runs yet."
}

# `run<TAB>started` lines for the fish completion of a run number.
complete_runs() {
  [[ -n ${sessions[${1:-}]:-} ]] || return 0
  local session n=0
  while IFS= read -r session; do
    n=$((n + 1))
    printf '%s\t%s\n' "$n" "$(run_time "$session")"
  done < <(session_files "$1")
}

open_session() {
  local session
  session=$(session_file "$1" "${2:-}")
  rm -f "$state_root/$1/unread"
  # A resumed session restores the tool loadout it ran with, which for a job
  # is the job's allowlist, often none. `--tools '*'` gives the person at the
  # keyboard every tool instead. Hidden MCP tools stay hidden.
  exec "$pi" --session "$session" --tools '*'
}

render() {
  if [[ -t 1 ]]; then
    glow -p -
  else
    cat
  fi
}

show_answer() {
  local name=$1 n=${2:-1} answer=$state_root/$1/answer.md
  if [[ -n ${notify[$name]:-} && $n == 1 && -e $answer ]]; then
    render <"$answer"
  elif [[ -n ${sessions[$name]:-} ]]; then
    local session
    session=$(session_file "$name" "$n")
    session_answer "$session" | render
  elif [[ -n ${notify[$name]:-} ]]; then
    die "'$name' has no answer yet. Run 'pi-job run $name' to make one."
  else
    die "'$name' keeps no answer. Set pi.jobs.$name.notify."
  fi
  rm -f "$state_root/$name/unread"
}

run_job() {
  systemctl --user start --no-block "pi-job-$1.service"
  echo "Started pi-job-$1. Follow it with: pi-job log $1 -f"
}

show_log() {
  local name=$1
  shift
  rm -f "$state_root/$name/failed"
  if [[ $# -eq 0 ]]; then
    set -- -e
  fi
  exec journalctl --user -u "pi-job-$name.service" "$@"
}

command=${1:-list}
[[ $# -gt 0 ]] && shift

case $command in
  list)
    at_most 0 list "$@"
    list
    ;;
  history)
    need_job "${1:-}"
    at_most 1 history "$@"
    need_sessions "$1"
    history "$1"
    ;;
  open)
    need_job "${1:-}"
    at_most 2 open "$@"
    need_sessions "$1"
    open_session "$1" "${2:-}"
    ;;
  show)
    need_job "${1:-}"
    at_most 2 show "$@"
    show_answer "$1" "${2:-}"
    ;;
  run)
    need_job "${1:-}"
    at_most 1 run "$@"
    run_job "$1"
    ;;
  log)
    need_job "${1:-}"
    show_log "$@"
    ;;
  __complete-runs) complete_runs "${1:-}" ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
