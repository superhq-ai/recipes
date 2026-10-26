# Step 2: the chromium service declared in step 1 is running by now. Prove
# the DevTools endpoint answers and that the browser renders a page while
# the VM is offline, as the unprivileged user.
set -eu
echo "==> DevTools version"
curl -sf http://127.0.0.1:9222/json/version
echo

echo "==> Offline screenshot as the browser user"
runuser -u browser -- chromium --headless=new --disable-gpu --no-first-run --log-level=3 \
  --user-data-dir=/tmp/check-profile --screenshot=/tmp/check.png \
  --window-size=400,300 'data:text/html,<h1>shuru</h1>'
test -s /tmp/check.png && echo "screenshot ok"
rm -rf /tmp/check-profile /tmp/check.png
