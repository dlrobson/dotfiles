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
       pi-job open <name>
       pi-job show <name>
       pi-job run <name>
       pi-job log <name> [journalctl options]

  list   Each job with its state, last run and next run (the default)
  open   Open the job's newest session in Pi and mark it read
  show   Print the job's latest answer and mark it read
  run    Start the job now instead of waiting for its timer
  log    Show the job's journal, ending at the newest lines, and clear
         its failed mark. Options such as -f replace the default -e.

A job's state is `new` (an unread answer), `failed` (the last run
failed), `read`, or `-` (no answer yet). Only jobs with `notify` set
record a state or an answer.
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

open_session() {
  local dir=${sessions[$1]:-} session
  [[ -n $dir ]] || die "'$1' does not keep sessions. Set pi.jobs.$1.notify or sessionDir."
  # Session file names start with their creation time, so the last in sort
  # order is the newest. Opened by path because `pi --continue` only finds
  # sessions started in the current directory.
  session=$(find "$dir" -name '*.jsonl' 2>/dev/null | sort | tail -n 1 || true)
  [[ -n $session ]] || die "'$1' has no session yet. Run 'pi-job run $1' to make one."
  rm -f "$state_root/$1/unread"
  # A resumed session restores the tool loadout it ran with, which for a job
  # is the job's allowlist, often none. `--tools '*'` gives the person at the
  # keyboard every tool instead. Hidden MCP tools stay hidden.
  exec "$pi" --session "$session" --tools '*'
}

show_answer() {
  [[ -n ${notify[$1]:-} ]] || die "'$1' does not keep its answer. Set pi.jobs.$1.notify."
  local answer=$state_root/$1/answer.md
  [[ -e $answer ]] || die "'$1' has no answer yet. Run 'pi-job run $1' to make one."
  cat "$answer"
  rm -f "$state_root/$1/unread"
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
  list) list ;;
  open)
    need_job "${1:-}"
    open_session "$1"
    ;;
  show)
    need_job "${1:-}"
    show_answer "$1"
    ;;
  run)
    need_job "${1:-}"
    run_job "$1"
    ;;
  log)
    need_job "${1:-}"
    show_log "$@"
    ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
