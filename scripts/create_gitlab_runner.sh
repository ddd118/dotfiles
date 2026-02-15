#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    cat <<'USAGE' >&2
使い方:
  ./create_gitlab_runner.sh [options]

例:
  # (レガシー) registration token で Runner を2つ登録（同一ホスト / 1コンテナ / 1つの config.toml に複数 [[runners]]）
  export REGISTRATION_TOKEN="<runner registration token>"
  ./create_gitlab_runner.sh \
    -n docker-runner-01 -n docker-runner-02 \
    --runner-version latest \
    --docker-version 29.1.3-cli

オプション:
  -i, --interactive       : 対話モードで登録を行う（token未指定でもOK）
  --keep-runner           : 既存 runner を保持する
  --keep-config           : 既存 config.toml を消さずに追記する（デフォルト: 消して作り直す）
  -n, --name <name>       : runner の名前（複数回指定可 / デフォルト: docker-runner-01）
  -t, --tags <tag_list>   : runner の tags（デフォルト: docker）
  --url <gitlab_url>      : GitLab URL
  --token <token>         : Runner token を直接指定（envより優先）
  --runner-version <ver>  : gitlab/gitlab-runner イメージのバージョン（デフォルト: latest）
  --docker-version <ver>  : docker イメージのバージョン（デフォルト: 29.1.3-cli）
  --container-name <name> : runner コンテナ名（デフォルト: gitlab-runner）
  --config-dir <path>     : config ディレクトリ（デフォルト: /srv/gitlab-runner/config）
  --cache-dir <path>      : cache ディレクトリ（デフォルト: /srv/gitlab-runner/cache）

事前に（非対話モード）:
  export REGISTRATION_TOKEN="(legacy) runner registration token"
    または
  export RUNNER_TOKEN="(new) runner authentication token (glrt-... )"

注意:
  - RUNNER_TOKEN が glrt- で始まる（runner authentication token）の場合、tag/locked/run-untagged 等は UI / API 側で設定する必要があります。
  - register を複数回実行すると config.toml に [[runners]] が追記されます。
USAGE
}

# --------------------
# defaults
# --------------------
GITLAB_URL="${GITLAB_URL:-}"
RUNNER_VERSION="latest"
DOCKER_VERSION="29.1.3-cli"
RUNNER_TAGS="docker"

CONFIG_DIR="/srv/gitlab-runner/config"
CACHE_DIR="/srv/gitlab-runner/cache"
CONTAINER_NAME="gitlab-runner"

interactive=false
unregister=true
keep_config=false

# allow multiple
RUNNER_NAMES=()

# token: accept both names for backward compatibility
RUNNER_TOKEN="${RUNNER_TOKEN:-${REGISTRATION_TOKEN:-}}"

# --------------------
# args
# --------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    -i | --interactive)
        interactive=true
        shift
        ;;
    --keep-runner)
        unregister=false
        shift
        ;;
    --keep-config)
        keep_config=true
        shift
        ;;
    -n | --name)
        RUNNER_NAMES+=("$2")
        shift 2
        ;;
    -t | --tags)
        RUNNER_TAGS="$2"
        shift 2
        ;;
    --url)
        GITLAB_URL="$2"
        shift 2
        ;;
    --token)
        RUNNER_TOKEN="$2"
        shift 2
        ;;
    --runner-version)
        RUNNER_VERSION="$2"
        shift 2
        ;;
    --docker-version)
        DOCKER_VERSION="$2"
        shift 2
        ;;
    --container-name)
        CONTAINER_NAME="$2"
        shift 2
        ;;
    --config-dir)
        CONFIG_DIR="$2"
        shift 2
        ;;
    --cache-dir)
        CACHE_DIR="$2"
        shift 2
        ;;
    *)
        echo "Unknown arg: $1" >&2
        usage
        exit 2
        ;;
    esac
done

if [[ ${#RUNNER_NAMES[@]} -eq 0 ]]; then
    RUNNER_NAMES=("docker-runner-01")
fi

# URL は必須
if [[ -z "${GITLAB_URL}" ]]; then
    echo "please specify GitLab URL via --url or GITLAB_URL env" >&2
    exit 1
fi

# 非対話モードは token 必須
if [[ "${interactive}" != "true" ]]; then
    if [[ -z "${RUNNER_TOKEN}" ]]; then
        echo "please export RUNNER_TOKEN or REGISTRATION_TOKEN (or pass --token)" >&2
        exit 1
    fi
fi

sudo mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}"

# 先に runner コンテナは落としておく（設定書き換え時の競合回避）
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

CONFIG_TOML="${CONFIG_DIR}/config.toml"

if [[ "${unregister}" == "true" ]]; then
    if [[ -f "${CONFIG_TOML}" ]]; then
        echo "[INFO] unregistering runners from ${CONFIG_TOML}" >&2
        docker run --rm \
            -v "${CONFIG_DIR}:/etc/gitlab-runner" \
            "gitlab/gitlab-runner:${RUNNER_VERSION}" unregister --all-runners
    else
        echo "[WARN] ${CONFIG_TOML} not found. skip unregister." >&2
    fi
fi

# デフォルトは『作り直し』。--keep-config を付けた時だけ追記する
if [[ "${keep_config}" != "true" ]]; then
    sudo rm -f "${CONFIG_TOML}"
fi

# runner template（docker executor の共通設定）
sudo tee "${CONFIG_DIR}/runner.template.toml" >/dev/null <<TOML
[[runners]]
  executor = "docker"
  [runners.feature_flags]
    FF_NETWORK_PER_BUILD = true
  [runners.docker]
    image = "docker:${DOCKER_VERSION}"
    privileged = true
    tls_verify = false
    volumes = ["/cache"]
    pull_policy = "if-not-present"
TOML

# token の種類で register の引数を切り替える
# * glrt-...: runner authentication token（推奨）
# * それ以外: runner registration token（レガシー）
TOKEN_FLAG="--registration-token"
SERVER_SIDE_FLAGS=()

if [[ -n "${RUNNER_TOKEN}" && "${RUNNER_TOKEN}" == glrt-* ]]; then
    TOKEN_FLAG="--token"
    echo "[INFO] Detected runner authentication token (glrt-*). tag/locked/run-untagged 等は GitLab UI / API 側で設定してください。" >&2
else
    # legacy registration token の場合のみ server-side flags を渡す
    SERVER_SIDE_FLAGS=(
        --tag-list "${RUNNER_TAGS}"
        --run-untagged="false"
        --locked="false"
    )
fi

if [[ "${interactive}" == "true" ]]; then
    # interactive registration
    # ? このモードはプロンプトで token / name / executor 等を聞かれる。
    docker run --rm -it \
        -v "${CONFIG_DIR}:/etc/gitlab-runner" \
        "gitlab/gitlab-runner:${RUNNER_VERSION}" register \
        --template-config /etc/gitlab-runner/runner.template.toml
else
    # non-interactive registration (複数 Runner 対応)
    for name in "${RUNNER_NAMES[@]}"; do
        echo "[INFO] registering runner: ${name}" >&2
        docker run --rm \
            -v "${CONFIG_DIR}:/etc/gitlab-runner" \
            "gitlab/gitlab-runner:${RUNNER_VERSION}" register \
            --non-interactive \
            --url "${GITLAB_URL}" \
            ${TOKEN_FLAG} "${RUNNER_TOKEN}" \
            --executor "docker" \
            --description "${name}" \
            --docker-image "docker:${DOCKER_VERSION}" \
            --docker-privileged \
            --template-config /etc/gitlab-runner/runner.template.toml \
            "${SERVER_SIDE_FLAGS[@]}"
    done
fi

# Runner 本体（Runner が job container を起動するため host docker.sock が必要）
#
# NOTE:
#   /var/run/docker.sock は mode=660 のことが多く、sock の GID に属していないとアクセスできません。
#   WSL + Docker Desktop などではコンテナ内で見える sock の GID が環境により変わることがあるため、
#   起動時にホスト側の sock GID を取得して --group-add で付与します。
DOCKER_SOCK_GID="$(stat -c %g /var/run/docker.sock)"
docker run -d --name "${CONTAINER_NAME}" --restart always \
    --group-add "${DOCKER_SOCK_GID}" \
    -v "${CONFIG_DIR}:/etc/gitlab-runner" \
    -v "${CACHE_DIR}:/cache" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "gitlab/gitlab-runner:${RUNNER_VERSION}"

# ? 登録されている Runner を表示
if [[ -f "${CONFIG_TOML}" ]]; then
    docker run --rm \
        -v "${CONFIG_DIR}:/etc/gitlab-runner" \
        "gitlab/gitlab-runner:${RUNNER_VERSION}" list || true
fi
