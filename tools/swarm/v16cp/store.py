from __future__ import annotations

import base64
import json
import random
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Callable, Mapping

from .core import GRAPH_PATH, ConflictError, NotFoundError, ValidationError, fmt, safe_path, validate_data_only, validate_graph


@dataclass(frozen=True)
class StoredValue:
    value: dict[str, Any]
    version: str


class MemoryStore:
    def __init__(self):
        self._data: dict[str, StoredValue] = {}
        self._counter = 0
        self._lock = threading.RLock()

    def _version(self) -> str:
        self._counter += 1
        return str(self._counter)

    def get(self, path: str) -> StoredValue:
        with self._lock:
            if path not in self._data: raise NotFoundError(path)
            item = self._data[path]
            return StoredValue(json.loads(json.dumps(item.value)), item.version)

    def create(self, path: str, value: Mapping[str, Any], message: str = "swarm v16: create") -> StoredValue:
        with self._lock:
            if path in self._data: raise ConflictError(path)
            item = StoredValue(json.loads(json.dumps(dict(value))), self._version()); self._data[path] = item
            return StoredValue(json.loads(json.dumps(item.value)), item.version)

    def update(self, path: str, value: Mapping[str, Any], expected_version: str, message: str = "swarm v16: update") -> StoredValue:
        with self._lock:
            if path not in self._data: raise NotFoundError(path)
            if self._data[path].version != expected_version: raise ConflictError(path)
            item = StoredValue(json.loads(json.dumps(dict(value))), self._version()); self._data[path] = item
            return StoredValue(json.loads(json.dumps(item.value)), item.version)


class GitHubContentsStore:
    RETRYABLE = {429, 500, 502, 503, 504}

    def __init__(self, repository: str, token: str, branch: str = "swarm-control", max_retries: int = 4):
        if repository.count("/") != 1 or not token: raise ValidationError("repository owner/name and token required")
        self.repository = repository; self.owner, self.repo = repository.split("/", 1); self.token = token; self.branch = branch; self.max_retries = max_retries

    def _request(self, method: str, path: str, payload: Mapping[str, Any] | None = None) -> Any:
        body = None if payload is None else json.dumps(payload).encode()
        for attempt in range(self.max_retries + 1):
            req = urllib.request.Request("https://api.github.com" + path, method=method, data=body, headers={"Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "unrendered-swarm-v16", "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=30) as response:
                    raw = response.read(); return None if not raw else json.loads(raw.decode())
            except urllib.error.HTTPError as exc:
                raw = exc.read().decode(errors="replace"); retry = exc.headers.get("Retry-After") if exc.headers else None; secondary = exc.code == 403 and ("secondary rate limit" in raw.lower() or retry)
                if attempt < self.max_retries and (exc.code in self.RETRYABLE or secondary):
                    delay = float(retry) if retry and retry.isdigit() else .4 * (2 ** attempt); time.sleep(delay + random.uniform(0, .2)); continue
                error = RuntimeError(f"GitHub API {method} {path} failed: HTTP {exc.code}: {raw[:600]}"); setattr(error, "status", exc.code); raise error from exc
            except urllib.error.URLError as exc:
                if attempt < self.max_retries: time.sleep(.4 * (2 ** attempt) + random.uniform(0, .2)); continue
                raise RuntimeError(f"GitHub transport failure: {exc}") from exc

    def _api_path(self, path: str) -> str:
        return f"/repos/{self.owner}/{self.repo}/contents/{urllib.parse.quote(safe_path(path), safe='/')}"

    @staticmethod
    def _decode_payload(payload: Mapping[str, Any]) -> dict[str, Any]:
        content = payload.get("content"); encoding = payload.get("encoding", "base64")
        if not isinstance(content, str) or not content: raise ValidationError("state payload omitted content")
        try:
            if encoding == "base64": raw = base64.b64decode("".join(content.split()), validate=True).decode()
            elif encoding in {"utf-8", "utf8"}: raw = content
            else: raise ValidationError("unsupported state encoding")
            value = json.loads(raw)
        except ValidationError: raise
        except Exception as exc: raise ValidationError("state file invalid JSON") from exc
        if not isinstance(value, dict): raise ValidationError("state file must contain object")
        return value

    def _blob(self, sha: str) -> dict[str, Any]:
        if not isinstance(sha, str) or not sha: raise ValidationError("state file missing blob SHA")
        payload = self._request("GET", f"/repos/{self.owner}/{self.repo}/git/blobs/{urllib.parse.quote(sha, safe='')}")
        if not isinstance(payload, dict) or payload.get("sha") not in {None, sha}: raise ValidationError("state blob SHA mismatch")
        return self._decode_payload(payload)

    def get(self, path: str) -> StoredValue:
        try: payload = self._request("GET", self._api_path(path) + "?" + urllib.parse.urlencode({"ref": self.branch}))
        except RuntimeError as exc:
            if getattr(exc, "status", None) == 404: raise NotFoundError(path) from exc
            raise
        if not isinstance(payload, dict) or payload.get("type") != "file" or not isinstance(payload.get("sha"), str): raise ValidationError("bad GitHub contents response")
        value = self._decode_payload(payload) if payload.get("content") else self._blob(payload["sha"])
        return StoredValue(value, payload["sha"])

    def create(self, path: str, value: Mapping[str, Any], message: str = "swarm v16: create") -> StoredValue:
        validate_data_only(value); content = base64.b64encode((json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + "\n").encode()).decode()
        try: response = self._request("PUT", self._api_path(path), {"message": message, "content": content, "branch": self.branch})
        except RuntimeError as exc:
            if getattr(exc, "status", None) in {409, 422}: raise ConflictError(path) from exc
            raise
        sha = ((response or {}).get("content") or {}).get("sha")
        if not isinstance(sha, str): raise ValidationError("create response omitted SHA")
        return StoredValue(dict(value), sha)

    def update(self, path: str, value: Mapping[str, Any], expected_version: str, message: str = "swarm v16: update") -> StoredValue:
        validate_data_only(value); content = base64.b64encode((json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + "\n").encode()).decode()
        try: response = self._request("PUT", self._api_path(path), {"message": message, "content": content, "branch": self.branch, "sha": expected_version})
        except RuntimeError as exc:
            if getattr(exc, "status", None) in {409, 422}: raise ConflictError(path) from exc
            if getattr(exc, "status", None) == 404: raise NotFoundError(path) from exc
            raise
        sha = ((response or {}).get("content") or {}).get("sha")
        if not isinstance(sha, str): raise ValidationError("update response omitted SHA")
        return StoredValue(dict(value), sha)


class MissionGraphStore:
    def __init__(self, store: Any, path: str = GRAPH_PATH, max_retries: int = 64):
        if max_retries < 1:
            raise ValidationError("Mission Graph CAS retry budget must be positive")
        self.store = store; self.path = path; self.max_retries = max_retries

    def load(self) -> tuple[dict[str, Any], str]:
        stored = self.store.get(self.path); return validate_graph(stored.value), stored.version

    def ensure(self, seed: Mapping[str, Any]) -> tuple[dict[str, Any], str]:
        try: return self.load()
        except NotFoundError:
            graph = validate_graph(seed)
            try: stored = self.store.create(self.path, graph, "swarm v16: initialize Mission Graph")
            except ConflictError: return self.load()
            return validate_graph(stored.value), stored.version

    def mutate(self, mutator: Callable[[dict[str, Any]], Any], *, seed: Mapping[str, Any] | None = None, message: str = "swarm v16: update Mission Graph", now=None) -> tuple[dict[str, Any], Any]:
        last: Exception | None = None
        for _ in range(self.max_retries):
            if seed is not None:
                graph, version = self.ensure(seed)
            else:
                graph, version = self.load()
            working = json.loads(json.dumps(graph)); result = mutator(working); working["revision"] = graph["revision"] + 1; working["updatedAt"] = fmt(now); validate_graph(working)
            try: stored = self.store.update(self.path, working, version, message)
            except ConflictError as exc: last = exc; continue
            return validate_graph(stored.value), result
        raise ConflictError("Mission Graph CAS retry budget exhausted") from last
