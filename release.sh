#!/usr/bin/env bash
# Cut a new release of the lsec-action.
#
# Usage: ./release.sh <version> [--dry-run] [--allow-dirty]
#
#   version       semver without the v prefix, e.g. 0.1.0
#   --dry-run     print every git/gh command without executing it
#   --allow-dirty stage all changes and commit them as the release commit
#
# Steps:
#   1. validate environment (git, gh, clean tree, default branch, no tag clash)
#   2. (optional) stage and commit pending changes as "chore: release vX.Y.Z"
#   3. push HEAD to origin
#   4. create annotated tag vX.Y.Z
#   5. fast-forward the major-version tag (vX) to HEAD
#   6. push both tags (vX is force-pushed)
#   7. create the GitHub Release with auto-generated notes
set -euo pipefail

DRY_RUN=0
ALLOW_DIRTY=0
VERSION=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)     DRY_RUN=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    -h|--help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "error: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [ -n "$VERSION" ]; then
        echo "error: unexpected positional argument: $1" >&2
        exit 2
      fi
      VERSION="$1"
      ;;
  esac
  shift
done

if [ -z "$VERSION" ]; then
  echo "error: version is required (e.g. ./release.sh 0.1.0)" >&2
  exit 2
fi

# Strip leading v if the caller included it.
VERSION="${VERSION#v}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "error: '$VERSION' is not a valid semver (expected X.Y.Z[-pre])" >&2
  exit 2
fi

TAG="v$VERSION"
MAJOR="v${VERSION%%.*}"

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '+ %s\n' "$*"
  else
    printf '+ %s\n' "$*"
    "$@"
  fi
}

# ---- preflight ----

command -v git >/dev/null || { echo "error: git not found" >&2; exit 2; }
command -v gh  >/dev/null || { echo "error: gh CLI not found (https://cli.github.com)" >&2; exit 2; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "error: not a git repo" >&2; exit 2; }

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || echo main)

if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
  echo "error: must release from $DEFAULT_BRANCH (currently on $CURRENT_BRANCH)" >&2
  exit 2
fi

echo "Fetching origin..."
run git fetch --tags origin

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "error: tag $TAG already exists locally" >&2
  exit 2
fi

if git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  echo "error: tag $TAG already exists on origin" >&2
  exit 2
fi

DIRTY=0
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  DIRTY=1
fi

if [ "$DIRTY" -eq 1 ] && [ "$ALLOW_DIRTY" -eq 0 ]; then
  echo "error: working tree is dirty. Commit your changes first, or rerun with --allow-dirty" >&2
  git status --short
  exit 2
fi

# Ensure HEAD isn't behind origin (we may be ahead — that's fine, we'll push).
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH" 2>/dev/null || echo "")
if [ -n "$REMOTE" ]; then
  BASE=$(git merge-base HEAD "origin/$DEFAULT_BRANCH")
  if [ "$BASE" != "$REMOTE" ]; then
    echo "error: local $DEFAULT_BRANCH is behind origin/$DEFAULT_BRANCH; pull first" >&2
    exit 2
  fi
fi

# ---- summary + confirm ----

cat <<EOF

About to cut release:
  version    : $VERSION
  tag        : $TAG
  major tag  : $MAJOR (will move to HEAD)
  branch     : $CURRENT_BRANCH
  dry run    : $([ "$DRY_RUN" -eq 1 ] && echo yes || echo no)
  allow dirty: $([ "$ALLOW_DIRTY" -eq 1 ] && echo yes || echo no)

EOF

read -r -p "Proceed? [y/N] " ANSWER
case "$ANSWER" in
  y|Y|yes|YES) ;;
  *) echo "aborted"; exit 1 ;;
esac

# ---- commit (optional) ----

if [ "$DIRTY" -eq 1 ] && [ "$ALLOW_DIRTY" -eq 1 ]; then
  run git add -A
  run git commit -m "chore: release $TAG"
fi

# ---- push HEAD ----

run git push origin "$DEFAULT_BRANCH"

# ---- tag + push tags ----

run git tag -a "$TAG"   -m "Release $TAG"
run git tag -f -a "$MAJOR" -m "Track $MAJOR"

run git push origin "$TAG"
run git push origin "refs/tags/$MAJOR" --force

# ---- GitHub release ----

PREV_TAG=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | grep -v "^${TAG}$" | head -n1 || true)

NOTES_ARGS=(--generate-notes)
if [ -n "$PREV_TAG" ]; then
  NOTES_ARGS=(--generate-notes --notes-start-tag "$PREV_TAG")
fi

run gh release create "$TAG" \
  --title "$TAG" \
  --target "$DEFAULT_BRANCH" \
  "${NOTES_ARGS[@]}"

echo
echo "Released $TAG"
echo "Major tag $MAJOR now points at HEAD"
echo "Consumers can pin: AfaanBilal/lsec-action@$MAJOR  or  @$TAG"
