#!/usr/bin/env bash
# PreToolUse hook (Bash): block commands that print secrets or destroy things,
# and force a prompt for anything that publishes images to Docker Hub or
# changes shared infrastructure/history.
# Help/version forms always pass through, so `tofu destroy -help` still works.
set -uo pipefail

cmd="$(jq -r '.tool_input.command // empty' 2>/dev/null)"
[[ -z "$cmd" ]] && exit 0
raw="$cmd"

decide() { # $1 = deny|ask, $2 = reason
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# Split chained commands (; && || | &) into one segment per line, then drop
# segments that are plain help/version calls, so `tofu destroy -help | head`
# passes but `tofu destroy -help; tofu destroy` doesn't. Segments containing
# $( or backticks are never treated as help.
# shellcheck disable=SC2016 # literal $ and backticks in the pattern
cmd="$(sed -E 's/(\|\||&&|[;|&])/\n/g' <<<"$cmd" |
  grep -vE '^[^`$]*(^|[[:space:]])(--help|-help|-h|help|--version|-version|version)([[:space:]][^`$]*)?$' || true)"
[[ -z "$cmd" ]] && exit 0

has() { grep -qE "$1" <<<"$cmd"; }

# Start of a command: line start or after ; & | ( , then optional VAR=x prefixes
# and wrappers, so `grep "tofu destroy" README.md` doesn't match.
SEG='(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((mise[[:space:]]+(exec|x)[[:space:]]+(.*[[:space:]])?--|command|time|nohup|sudo)[[:space:]]+)?'
TF="${SEG}(tofu|terraform)[[:space:]](.*[[:space:]])?"
END='([[:space:]]|$|[;&|)])'
# Things that run the bake wrapper or bake itself.
BAKE="${SEG}(yarn[[:space:]]+(run[[:space:]]+)?build|node[[:space:]]+(\\./)?bin/bake\\.js|docker[[:space:]]+buildx[[:space:]]+(bake|f|build)|docker[[:space:]]+build)${END}"
JOLT="${SEG}(yarn[[:space:]]+(run[[:space:]]+)?)?jolt[[:space:]]"

# --- deny: prints secrets ---
has "${TF}output${END}" && has "${TF}output[[:space:]](.*[[:space:]])?-(json|raw|show-sensitive)" &&
  decide deny "tofu output -json/-raw/-show-sensitive prints sensitive values in plain text. Use plain 'tofu output' (redacted)."
has "${TF}state[[:space:]]+pull${END}" &&
  decide deny "tofu state pull prints the full state, including secrets."
has "${TF}show[[:space:]](.*[[:space:]])?-json" &&
  decide deny "tofu show -json includes sensitive values from state in plain text."
has "${SEG}aws[[:space:]]+secretsmanager[[:space:]]+get-secret-value" &&
  decide deny "Reading secret values is not allowed for agents."
has "${SEG}aws[[:space:]]+ssm[[:space:]]+get-parameters?(-by-path)?[[:space:]].*--with-decryption" &&
  decide deny "Decrypting SSM SecureString parameters (e.g. the Docker Hub password) is not allowed for agents."
has "${SEG}aws[[:space:]]+ecr[[:space:]]+get-login-password${END}" && ! grep -qE "get-login-password.*\\|[[:space:]]*docker[[:space:]]+login" <<<"$raw" &&
  decide deny "aws ecr get-login-password prints a registry token. Pipe it straight into docker login if you need it."
has "${SEG}gh[[:space:]]+auth[[:space:]]+token" &&
  decide deny "Printing the GitHub token is not allowed."
has "${SEG}(printenv|env)[[:space:]]*(\$|[;&|)])" &&
  decide deny "Dumping the environment would print credentials. Check specific non-secret variables instead."
has '(AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|GITHUB_TOKEN|GH_TOKEN|DOCKERHUB_TOKEN|DOCKERHUB_PASSWORD)' &&
  has "\\\$\\{?(AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|GITHUB_TOKEN|GH_TOKEN|DOCKERHUB_TOKEN|DOCKERHUB_PASSWORD)|${SEG}printenv[[:space:]]" &&
  decide deny "Don't print credential environment variables."
has "${SEG}(cat|less|more|head|tail|bat|strings|xxd|nl|jq)[[:space:]](.*)(\\.env([.[:space:]]|\$)|\\.tfvars|\\.tfstate|\\.docker/config\\.json)" &&
  decide deny "Don't print .env, .tfvars, state files or Docker credentials; they hold secrets."

# --- deny: irreversible ---
has "${TF}destroy${END}" &&
  decide deny "tofu destroy is blocked for agents. A human must run it."
has "${TF}apply[[:space:]](.*[[:space:]])?-destroy${END}" &&
  decide deny "tofu apply -destroy is blocked for agents. A human must run it."
has "${SEG}git[[:space:]]+push([[:space:]].*)?[[:space:]](--force[^[:space:]]*|-f)${END}" && has "${SEG}git[[:space:]]+push[[:space:]].*(master|main)${END}" &&
  decide deny "Force-pushing the default branch is blocked."
has "${SEG}rm[[:space:]]+(-[[:alpha:]]*r[[:alpha:]]*f|-[[:alpha:]]*f[[:alpha:]]*r)[[:alpha:]]*[[:space:]]+(/|~|~/|\\\$HOME|\\.|\\./|\\*)${END}" &&
  decide deny "Recursive delete of /, ~ or the repo root is blocked."
has "${SEG}gh[[:space:]]+repo[[:space:]]+delete" &&
  decide deny "Deleting GitHub repos is blocked for agents."

# --- ask: publishes images to Docker Hub ---
has "${SEG}yarn[[:space:]]+(run[[:space:]]+)?push${END}" &&
  decide ask "yarn push publishes images to Docker Hub (only PLATFORMS, default linux/amd64, replacing multi-platform tags). Needs human approval."
has "$BAKE" && has "(--push${END}|push=true|type=registry)" &&
  decide ask "This build pushes images to Docker Hub. Needs human approval."
has "${SEG}yarn[[:space:]]+(run[[:space:]]+)?build:remote${END}" &&
  decide ask "yarn build:remote starts the CodeBuild batch, which publishes images to Docker Hub. Needs human approval."
has "${JOLT}(.*[[:space:]])?(codebuild|ecs|nexcess|deploy|deploy-specific|push|combined|manifest)${END}" &&
  decide ask "This jolt command builds, pushes or deploys. Needs human approval."
has "${SEG}docker[[:space:]]+(image[[:space:]]+)?push${END}|${SEG}docker[[:space:]]+manifest[[:space:]]+(push|create)${END}|${SEG}docker[[:space:]]+buildx[[:space:]]+imagetools[[:space:]]+create${END}" &&
  decide ask "This writes tags or manifests to a registry. Needs human approval."
has "${SEG}gh[[:space:]]+workflow[[:space:]]+(run|enable|disable)${END}" &&
  decide ask "This triggers or toggles a GitHub workflow; Build and Push publishes to Docker Hub. Needs human approval."
has "${SEG}gh[[:space:]]+run[[:space:]]+(rerun|cancel)${END}" &&
  decide ask "This reruns or cancels a GitHub Actions run (which may publish images)."

# --- ask: pushing to master publishes images via CI ---
if has "${SEG}git[[:space:]]+push([[:space:]]|$)"; then
  has "${SEG}git[[:space:]]+push([[:space:]].*)?[[:space:]](--force[^[:space:]]*|-f)${END}" &&
    decide ask "Force push rewrites remote history."
  has "${SEG}git[[:space:]]+push[[:space:]].*(^|[[:space:]:+])(refs/heads/)?(master|main)${END}" &&
    decide ask "Pushing to master triggers the Build and Push workflow, which publishes images to Docker Hub."
  branch="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  if [[ "$branch" == "master" || "$branch" == "main" ]] &&
    has "${SEG}git[[:space:]]+push([[:space:]]+(-[^[:space:]]+|origin))*[[:space:]]*$"; then
    decide ask "You are on $branch: a bare git push triggers the Build and Push workflow, which publishes images."
  fi
fi

# --- ask: changes shared infrastructure or history ---
has "${TF}apply${END}" &&
  decide ask "data.tf only reads shared-infrastructure state; tofu apply is not part of this repo's workflow."
has "${TF}(import|taint|untaint|force-unlock)${END}" &&
  decide ask "This changes OpenTofu state."
has "${TF}state[[:space:]]+(rm|mv|push|replace-provider)${END}" &&
  decide ask "This changes OpenTofu state."
has "${TF}workspace[[:space:]]+(new|delete|select)${END}" &&
  decide ask "This changes the OpenTofu workspace."
has "${SEG}aws[[:space:]]+[[:alnum:]-]+[[:space:]]+(delete|terminate|put|create|update|modify|remove|attach|detach|reboot|stop|start|restore|tag|untag|batch-delete|retry)-" &&
  decide ask "This changes AWS resources (including starting CodeBuild builds)."
has "${SEG}aws[[:space:]]+s3[[:space:]]+(rm|rb|mv|sync|cp)${END}" &&
  decide ask "This writes to or deletes from S3."
has "${SEG}gh[[:space:]]+(repo[[:space:]]+(archive|rename|edit)|api[[:space:]].*(-X|--method)[[:space:]]*(DELETE|PATCH|PUT|POST))" &&
  decide ask "This changes GitHub settings."
has "${SEG}git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[[:alpha:]]*f)" &&
  decide ask "This discards local changes."

exit 0
