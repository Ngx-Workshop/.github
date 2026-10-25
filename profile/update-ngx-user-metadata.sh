#!/usr/bin/env bash

set -euo pipefail

readonly PACKAGE_NAME='@tmdjr/ngx-user-metadata'
readonly LOGGER_PACKAGE='@tmdjr/ngx-workshop-logger'
readonly LOGGER_VERSION='0.4.0'
readonly REQUIRED_NODE_MAJOR='22'
readonly REQUIRED_NPM_MAJOR='10'
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
publish=false
declare -a allowed_dirty_repos=()
declare -a repos=()

usage() {
  cat <<'EOF'
Usage: update-ngx-user-metadata.sh VERSION [options]

Updates every immediate child repository that declares @tmdjr/ngx-user-metadata.
The script pins the exact package and federation versions, regenerates lockfiles,
performs a clean npm ci, runs repository checks and a production build, and
optionally commits and pushes only after every repository passes.

Options:
  --publish              Commit and push all successfully validated repositories.
  --allow-dirty REPO     Incorporate supported existing changes in REPO. Repeatable.
  --workspace PATH       Workspace containing the repositories.
  -h, --help             Show this help.

Required runtime:
  Node.js 22 and npm 10, matching the GitHub Actions lockfile runtime.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

is_allowed_dirty_repo() {
  local candidate=$1
  local allowed
  for allowed in "${allowed_dirty_repos[@]}"; do
    [[ "$candidate" == "$allowed" ]] && return 0
  done
  return 1
}

is_supported_changed_file() {
  case "$1" in
    package.json|package-lock.json|webpack.config.js|README.md|docs/development.md)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

assert_supported_changes() {
  local repo=$1
  local file
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    is_supported_changed_file "$file" ||
      fail "$repo has an unsupported existing change: $file"
  done < <(
    {
      git -C "$workspace_root/$repo" diff --name-only
      git -C "$workspace_root/$repo" diff --cached --name-only
      git -C "$workspace_root/$repo" ls-files --others --exclude-standard
    } | sort -u
  )
}

[[ $# -gt 0 ]] || {
  usage
  exit 1
}
if [[ "$1" == '-h' || "$1" == '--help' ]]; then
  usage
  exit 0
fi

version=$1
shift
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  fail "VERSION must be an exact semantic version, for example 21.0.7"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)
      publish=true
      shift
      ;;
    --allow-dirty)
      [[ $# -ge 2 ]] || fail '--allow-dirty requires a repository name'
      allowed_dirty_repos+=("$2")
      shift 2
      ;;
    --workspace)
      [[ $# -ge 2 ]] || fail '--workspace requires a path'
      workspace_root="$(cd "$2" && pwd)"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

node_major=$(node -p 'process.versions.node.split(".")[0]')
npm_major=$(npm --version | cut -d. -f1)
[[ "$node_major" == "$REQUIRED_NODE_MAJOR" ]] ||
  fail "Node.js $REQUIRED_NODE_MAJOR is required; found $(node --version)"
[[ "$npm_major" == "$REQUIRED_NPM_MAJOR" ]] ||
  fail "npm $REQUIRED_NPM_MAJOR is required; found $(npm --version)"
npm view "$PACKAGE_NAME@$version" version --json |
  grep -q "\"$version\"" ||
  fail "$PACKAGE_NAME@$version is not available from the configured registry"

while IFS= read -r repo; do
  repos+=("$repo")
done < <(
  node - "$workspace_root" "$PACKAGE_NAME" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const [root, packageName] = process.argv.slice(2);
for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  const packagePath = path.join(root, entry.name, 'package.json');
  if (!fs.existsSync(packagePath)) continue;
  const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
  if (pkg.dependencies?.[packageName] || pkg.devDependencies?.[packageName]) {
    console.log(entry.name);
  }
}
NODE
)

[[ ${#repos[@]} -gt 0 ]] || fail "No $PACKAGE_NAME consumers found in $workspace_root"
printf 'Discovered %d consumer repositories:\n' "${#repos[@]}"
printf '  %s\n' "${repos[@]}"

for repo in "${repos[@]}"; do
  repo_path="$workspace_root/$repo"
  git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fail "$repo is not a Git worktree"
  [[ -f "$repo_path/webpack.config.js" ]] ||
    fail "$repo declares $PACKAGE_NAME but has no webpack.config.js"
  if [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
    is_allowed_dirty_repo "$repo" ||
      fail "$repo has existing changes; use --allow-dirty $repo only after reviewing them"
    assert_supported_changes "$repo"
  fi
done

for repo in "${repos[@]}"; do
  repo_path="$workspace_root/$repo"
  printf '\n[%s] Updating to %s\n' "$repo" "$version"
  node - "$repo_path" "$PACKAGE_NAME" "$version" "$LOGGER_PACKAGE" "$LOGGER_VERSION" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const [repoPath, packageName, version, loggerPackage, loggerVersion] = process.argv.slice(2);
const packagePath = path.join(repoPath, 'package.json');
const webpackPath = path.join(repoPath, 'webpack.config.js');
let packageText = fs.readFileSync(packagePath, 'utf8');
const escapedName = packageName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const escapedLogger = loggerPackage.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const packagePattern = new RegExp(`("${escapedName}"\\s*:\\s*")[^"]+(")`, 'g');
const packageMatches = packageText.match(packagePattern) ?? [];
if (packageMatches.length !== 1) {
  throw new Error(`${packagePath}: expected one ${packageName} declaration, found ${packageMatches.length}`);
}
packageText = packageText.replace(packagePattern, `$1${version}$2`);
const loggerPattern = new RegExp(`("${escapedLogger}"\\s*:\\s*")[^"]+(")`, 'g');
const loggerMatches = packageText.match(loggerPattern) ?? [];
if (loggerMatches.length > 1) {
  throw new Error(`${packagePath}: expected at most one ${loggerPackage} declaration`);
}
if (loggerMatches.length === 1) {
  packageText = packageText.replace(loggerPattern, `$1${loggerVersion}$2`);
} else {
  const metadataLine = new RegExp(`^(\\s*)"${escapedName}"\\s*:\\s*"[^"]+",\\s*$`, 'm');
  if (!metadataLine.test(packageText)) {
    throw new Error(`${packagePath}: could not place ${loggerPackage} beside ${packageName}`);
  }
  packageText = packageText.replace(
    metadataLine,
    `$&\n$1"${loggerPackage}": "${loggerVersion}",`,
  );
}
fs.writeFileSync(packagePath, packageText);

let webpackText = fs.readFileSync(webpackPath, 'utf8');
const webpackPattern = new RegExp(
  `(['"]${escapedName}['"]\\s*:\\s*\\{[^}]*?requiredVersion\\s*:\\s*['"])[^'"]+(['"])`,
  'g',
);
const webpackMatches = webpackText.match(webpackPattern) ?? [];
if (webpackMatches.length !== 1) {
  throw new Error(`${webpackPath}: expected one ${packageName} shared block, found ${webpackMatches.length}`);
}
webpackText = webpackText.replace(webpackPattern, `$1${version}$2`);
const loggerWebpackPattern = new RegExp(
  `(['"]${escapedLogger}['"]\\s*:\\s*\\{[^}]*?requiredVersion\\s*:\\s*['"])[^'"]+(['"])`,
  'g',
);
const loggerWebpackMatches = webpackText.match(loggerWebpackPattern) ?? [];
if (loggerWebpackMatches.length > 1) {
  throw new Error(`${webpackPath}: expected at most one ${loggerPackage} shared block`);
}
if (loggerWebpackMatches.length === 1) {
  webpackText = webpackText.replace(loggerWebpackPattern, `$1${loggerVersion}$2`);
} else {
  const metadataBlock = new RegExp(
    `(^\\s*['"]${escapedName}['"]\\s*:\\s*\\{[^}]*?^\\s*\\},)`,
    'm',
  );
  if (!metadataBlock.test(webpackText)) {
    throw new Error(`${webpackPath}: could not place ${loggerPackage} shared block`);
  }
  webpackText = webpackText.replace(
    metadataBlock,
    `$1\n\n    '${loggerPackage}': {\n` +
      `      singleton: true,\n` +
      `      strictVersion: true,\n` +
      `      requiredVersion: '${loggerVersion}',\n` +
      `    },`,
  );
}
fs.writeFileSync(webpackPath, webpackText);
NODE

  (
    cd "$repo_path"
    if [[ -L node_modules ]]; then
      fail "$repo/node_modules is a symbolic link; refusing to delete it"
    fi
    rm -rf node_modules
    npm install --package-lock-only
    npm ci

    node - "$PACKAGE_NAME" "$version" "$LOGGER_PACKAGE" "$LOGGER_VERSION" <<'NODE'
const fs = require('node:fs');
const [packageName, version, loggerPackage, loggerVersion] = process.argv.slice(2);
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const lock = JSON.parse(fs.readFileSync('package-lock.json', 'utf8'));
const section = pkg.dependencies?.[packageName] ? 'dependencies' : 'devDependencies';
if (pkg[section]?.[packageName] !== version) throw new Error('package.json is not pinned');
if (lock.packages['']?.[section]?.[packageName] !== version) throw new Error('lockfile root is not pinned');
if (lock.packages[`node_modules/${packageName}`]?.version !== version) {
  throw new Error('lockfile package version does not match');
}
const installed = JSON.parse(fs.readFileSync(`node_modules/${packageName}/package.json`, 'utf8'));
if (installed.version !== version) throw new Error('installed package version does not match');
if (pkg[section]?.[loggerPackage] !== loggerVersion) throw new Error('logger package is not pinned');
if (lock.packages['']?.[section]?.[loggerPackage] !== loggerVersion) {
  throw new Error('lockfile root logger is not pinned');
}
if (lock.packages[`node_modules/${loggerPackage}`]?.version !== loggerVersion) {
  throw new Error('lockfile logger version does not match');
}
const installedLogger = JSON.parse(fs.readFileSync(`node_modules/${loggerPackage}/package.json`, 'utf8'));
if (installedLogger.version !== loggerVersion) throw new Error('installed logger version does not match');
const config = require('./webpack.config.js');
const federation = config.plugins?.find(plugin => plugin.constructor.name === 'ModuleFederationPlugin');
const shared = (federation?.options ?? federation?._options)?.shared;
if (shared?.[packageName]?.requiredVersion !== version) {
  throw new Error('webpack requiredVersion does not match');
}
if (shared[packageName].singleton !== true || shared[packageName].strictVersion !== true) {
  throw new Error('webpack singleton/strictVersion settings changed');
}
if (shared?.[loggerPackage]?.requiredVersion !== loggerVersion) {
  throw new Error('webpack logger requiredVersion does not match');
}
if (shared[loggerPackage].singleton !== true || shared[loggerPackage].strictVersion !== true) {
  throw new Error('webpack logger singleton/strictVersion settings changed');
}
NODE

    if node -e "process.exit(require('./package.json').scripts?.['check:architecture'] ? 0 : 1)"; then
      npm run check:architecture
    fi
    if node -e "process.exit(require('./package.json').scripts?.['check:layout'] ? 0 : 1)"; then
      npm run check:layout
    fi

    output_path="dist/metadata-upgrade-${version//./-}"
    rm -rf "$output_path"
    npm run build -- --configuration production --output-path "$output_path"
    [[ -s "$output_path/index.html" ]] || fail "$repo build did not produce index.html"
    [[ -s "$output_path/3rdpartylicenses.txt" ]] ||
      fail "$repo build did not produce 3rdpartylicenses.txt"
    rm -rf "$output_path"
    git diff --check
  )
  printf '[%s] Validation passed\n' "$repo"
done

if [[ "$publish" == true ]]; then
  printf '\nAll repositories passed. Committing and pushing...\n'
  for repo in "${repos[@]}"; do
    repo_path="$workspace_root/$repo"
    assert_supported_changes "$repo"
    mapfile_command_output=$(
      {
        git -C "$repo_path" diff --name-only
        git -C "$repo_path" diff --cached --name-only
        git -C "$repo_path" ls-files --others --exclude-standard
      } | sort -u
    )
    [[ -n "$mapfile_command_output" ]] || {
      printf '[%s] No changes to publish\n' "$repo"
      continue
    }
    while IFS= read -r file; do
      [[ -n "$file" ]] && git -C "$repo_path" add -- "$file"
    done <<< "$mapfile_command_output"
    git -C "$repo_path" commit \
      -m "Upgrade ngx-user-metadata to $version" \
      --trailer 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
    git -C "$repo_path" push
    [[ -z "$(git -C "$repo_path" status --porcelain)" ]] ||
      fail "$repo is not clean after publishing"
    [[ "$(git -C "$repo_path" rev-parse HEAD)" == "$(git -C "$repo_path" rev-parse '@{upstream}')" ]] ||
      fail "$repo push did not synchronize its upstream"
    printf '[%s] Published\n' "$repo"
  done
else
  printf '\nAll repositories passed. Changes remain local; rerun with --publish to commit and push.\n'
fi
