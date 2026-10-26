# Step 2: pull one image so the checkpoint can run it with networking off.
# dockerd is already up: the service declared in step 1 starts at boot.
#
# nginxinc/nginx-unprivileged 1.31.7-alpine-slim, multi-arch index digest,
# runs as uid 101 and listens on 8080.
#
# A pull by digest is stored without the tag, so the tag is added afterwards.
# Without it, docker run by tag would try the registry and fail offline.
set -eu
REPO="nginxinc/nginx-unprivileged"
TAG="1.31.7-alpine-slim"
DIGEST="sha256:a8cb0f33d51fa107c96fd2bd3a71aaf564ec131e9d2bdf8700944f0ed8b170d7"

echo "==> Pulling ${REPO}:${TAG}@${DIGEST}"
docker pull "${REPO}:${TAG}@${DIGEST}"
docker tag "${REPO}@${DIGEST}" "${REPO}:${TAG}"
docker image ls --digests
