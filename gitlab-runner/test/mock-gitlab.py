"""A fake of the few GitLab API endpoints that GitLab Runner talks to.

Used by smoke-test.sh only (compose profile `test`). It accepts any runner
token, hands out exactly one job, records the job log and final state, and
answers "no jobs" after that. GET /-/state shows what happened.
"""

import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

JOB_ID = 1
JOB_TOKEN = "mock-job-token"

# $((6*7)) and /etc/alpine-release only expand inside the job container, so
# "smoke-ok 42 alpine-3." in the log proves the script really ran there.
JOB = {
    "id": JOB_ID,
    "token": JOB_TOKEN,
    "allow_git_fetch": False,
    "job_info": {"id": JOB_ID, "name": "smoke", "stage": "test", "project_id": 1, "project_name": "smoke"},
    "git_info": {
        "repo_url": "http://mock-gitlab:8080/smoke/smoke.git",
        "ref": "main",
        "sha": "0" * 40,
        "before_sha": "0" * 40,
        "ref_type": "branch",
        "refspecs": [],
        "depth": 1,
    },
    "runner_info": {"timeout": 600},
    "variables": [
        # nothing to clone: there is no repository behind this fake
        {"key": "GIT_STRATEGY", "value": "none", "public": True},
        {"key": "CI_JOB_ID", "value": str(JOB_ID), "public": True},
    ],
    "steps": [
        {
            "name": "script",
            "script": ['echo "smoke-ok $((6*7)) alpine-$(cat /etc/alpine-release)"'],
            "timeout": 600,
            "when": "on_success",
            "allow_failure": False,
        }
    ],
    "image": {"name": os.environ.get("JOB_IMAGE", "alpine:3.24.2")},
    "services": [],
    "artifacts": [],
    "cache": [],
    "credentials": [],
    "dependencies": [],
    "features": {"trace_sections": True},
}

lock = threading.Lock()
state = {"verify_calls": 0, "job_requests": 0, "job_served": False, "job_state": None, "trace": ""}


class Handler(BaseHTTPRequestHandler):
    @property
    def route(self):
        return self.path.split("?", 1)[0]

    def _body(self):
        return self.rfile.read(int(self.headers.get("Content-Length") or 0))

    def _send(self, status, payload=None, headers=None):
        data = b"" if payload is None else json.dumps(payload).encode()
        self.send_response(status)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        if payload is not None:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.route == "/-/health":
            return self._send(200, {"status": "ok"})
        if self.route == "/-/state":
            with lock:
                return self._send(200, state)
        self._send(404, {"message": "404 Not Found"})

    def do_POST(self):
        body = self._body()
        if self.route == "/api/v4/runners/verify":
            token = json.loads(body or b"{}").get("token", "")
            with lock:
                state["verify_calls"] += 1
            return self._send(200, {"id": 1, "token": token, "token_expires_at": None})
        if self.route == "/api/v4/jobs/request":
            with lock:
                state["job_requests"] += 1
                if not state["job_served"]:
                    state["job_served"] = True
                    return self._send(201, JOB)
            return self._send(204, headers={"X-GitLab-Last-Update": "mock"})
        self._send(404, {"message": "404 Not Found"})

    def do_PATCH(self):
        body = self._body()
        if self.route == f"/api/v4/jobs/{JOB_ID}/trace":
            start = int((self.headers.get("Content-Range") or "0-0").split("-")[0])
            with lock:
                state["trace"] = state["trace"][:start] + body.decode(errors="replace")
                end = len(state["trace"].encode())
            return self._send(202, headers={"Range": f"0-{end}", "Job-Status": "running"})
        self._send(404, {"message": "404 Not Found"})

    def do_PUT(self):
        body = self._body()
        if self.route == f"/api/v4/jobs/{JOB_ID}":
            with lock:
                state["job_state"] = json.loads(body or b"{}").get("state")
            return self._send(200, headers={"Job-Status": state["job_state"] or "running"})
        self._send(404, {"message": "404 Not Found"})

    def do_DELETE(self):
        # unregister
        if self.route.startswith("/api/v4/runners"):
            return self._send(204)
        self._send(404, {"message": "404 Not Found"})


if __name__ == "__main__":
    print("mock GitLab API listening on :8080")
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
