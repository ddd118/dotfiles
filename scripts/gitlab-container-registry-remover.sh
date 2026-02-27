#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE' >&2
使い方:
  ./image-remover.sh [options]

例:
  # 壊れたタグに空のイメージを上書きする
  export CI_REGISTRY="registry.example.com"
  export CI_REGISTRY_USER="<username>"
  export CI_REGISTRY_PASSWORD="<PAT>"
  ./image-remover.sh \
    -n docker-runner-01 -n docker-runner-02 \
    --runner-version latest \
    --docker-version 29.1.3-cli

オプション:
  -i, --image-repo        : イメージのリポジトリ（IMAGE_REPO 環境変数を使わない場合必須）

USAGE
}

# --------------------
# args
# --------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  -r | --image-repo)
    IMAGE_REPO="$2"
    shift 2
    ;;
  *)
    echo "Unknown arg: $1" >&2
    usage
    exit 2
    ;;
  esac
done


# 必須
: "${IMAGE_REPO:?set IMAGE_REPO e.g. registry.example.com/group/project/tdx-app-ci}"

# 任意
: "${BUILDX_DRIVER_IMAGE:=moby/buildkit:buildx-stable-1}"

tags=()

TAGS_FILE=./tags.txt
if [ -n "${TAGS_FILE:-}" ]; then
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        tags+=("$line")
    done <"$TAGS_FILE"
fi

if [ -n "${TAGS:-}" ]; then
    for tag in $TAGS; do
        tags+=("$tag")
    done
fi

if [ "${#tags[@]}" -eq 0 ]; then
    echo "No tags provided. Set TAGS or TAGS_FILE." >&2
    exit 1
fi

# ログイン（GitLab registry向け。必要に応じて環境変数を設定）
if [ -n "${CI_REGISTRY:-}" ] && [ -n "${CI_REGISTRY_USER:-}" ] && [ -n "${CI_REGISTRY_PASSWORD:-}" ]; then
    echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
fi

BUILDX_BUILDER_NAME="remover-builder-$$"
BUILD_CONTEXT_DIR="$(mktemp -d -p /tmp "image-remover-XXXX")"
cleanup() {
    docker buildx rm "$BUILDX_BUILDER_NAME" >/dev/null 2>&1 || true
    rm -rf "$BUILD_CONTEXT_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker buildx create --name "$BUILDX_BUILDER_NAME" \
    --driver docker-container \
    --driver-opt "image=${BUILDX_DRIVER_IMAGE}" \
    --buildkitd-flags "--allow-insecure-entitlement=network.host" \
    --use >/dev/null

docker buildx inspect "$BUILDX_BUILDER_NAME" --bootstrap >/dev/null

cat >"$BUILD_CONTEXT_DIR/Dockerfile" <<'EOF'
FROM scratch
LABEL cleanup="true"
EOF

for tag in "${tags[@]}"; do
    build_image="${IMAGE_REPO}:${tag}"
    echo "Pushing ${build_image}"
    docker buildx build \
        --provenance=false \
        --builder "$BUILDX_BUILDER_NAME" \
        -t "$build_image" \
        --push "$BUILD_CONTEXT_DIR"
done
