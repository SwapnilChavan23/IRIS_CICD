#!/usr/bin/env python3
"""Sync InterSystems IRIS source code between an instance and a git folder.

Uses the Atelier REST API (/api/atelier/v1) that ships with IRIS, so nothing
needs to be installed on the IRIS side.

  export  IRIS instance -> <workdir>/src   (writes/removes files, no git actions)
  import  <workdir>/src -> IRIS instance   (uploads changed docs, then compiles)
  status  show what differs between <workdir>/src and the instance

Connection settings come from environment variables (see .env.example):
  IRIS_HOST, IRIS_PORT, IRIS_NS, IRIS_USER, IRIS_PASS
"""

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# Document types kept in source control.
EXTENSIONS = {"cls", "mac", "inc", "int", "lut", "hl7", "x12", "dfi"}

# Packages that are system/product code mapped into USER - never exported.
EXCLUDED_PREFIXES = (
    "%", "Ens.", "EnsLib.", "EnsPortal.", "CSPX.", "HS.", "HSMOD.", "HSFHIR.",
    "INFORMATION.", "SchemaMap.", "Ens.Util.", "Ens.Rule.",
)


class Iris:
    def __init__(self, host, port, ns, user, password):
        self.base = f"http://{host}:{port}/api/atelier/v1/{urllib.parse.quote(ns)}"
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        self.headers = {"Authorization": f"Basic {token}", "Content-Type": "application/json"}

    def _call(self, method, path, body=None, query=None):
        url = self.base + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method, headers=self.headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            if e.code == 401:
                sys.exit(f"ERROR: 401 Unauthorized from {url} - check IRIS_USER/IRIS_PASS")
            if e.code == 404 and method == "GET" and path.startswith("/doc/"):
                return None
            detail = e.read().decode(errors="replace")[:500]
            sys.exit(f"ERROR: HTTP {e.code} {method} {url}\n{detail}")
        except urllib.error.URLError as e:
            sys.exit(f"ERROR: cannot reach {url}: {e.reason}")

    def list_docs(self):
        res = self._call("GET", "/docnames/*", query={"generated": 0, "mapped": 0})
        names = []
        for doc in res["result"]["content"]:
            name = doc["name"]
            ext = name.rsplit(".", 1)[-1].lower()
            if ext in EXTENSIONS and not name.startswith(EXCLUDED_PREFIXES):
                names.append(name)
        return sorted(names)

    def get_doc(self, name):
        res = self._call("GET", "/doc/" + urllib.parse.quote(name))
        if res is None:
            return None
        return res["result"]["content"]

    def put_doc(self, name, lines):
        res = self._call("PUT", "/doc/" + urllib.parse.quote(name),
                         body={"enc": False, "content": lines},
                         query={"ignoreConflict": 1})
        return res["status"].get("errors", [])

    def compile(self, names):
        return self._call("POST", "/action/compile", body=names, query={"flags": "cuk"})


def doc_to_path(src, name):
    """Demo.Pkg.MyClass.cls -> src/Demo/Pkg/MyClass.cls"""
    stem, ext = name.rsplit(".", 1)
    return src.joinpath(*stem.split(".")).with_name(stem.split(".")[-1] + "." + ext)


def path_to_doc(src, path):
    rel = path.relative_to(src)
    return ".".join(rel.parent.parts + (rel.stem,)) + rel.suffix


def local_docs(src):
    docs = {}
    for p in sorted(src.rglob("*")):
        if p.is_file() and p.suffix.lstrip(".").lower() in EXTENSIONS:
            docs[path_to_doc(src, p)] = p
    return docs


def read_lines(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip("\n").split("\n")


def normalize(lines):
    return [l.rstrip() for l in lines] if lines else lines


def cmd_export(iris, src):
    server = iris.list_docs()
    local = local_docs(src)
    written = 0
    for name in server:
        lines = iris.get_doc(name)
        path = doc_to_path(src, name)
        text = "\n".join(lines) + "\n"
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            print(f"  exported  {name}")
            written += 1
    removed = 0
    for name, path in local.items():
        if name not in server:
            path.unlink()
            print(f"  removed   {name}  (no longer on server)")
            removed += 1
    # tidy empty folders
    for d in sorted(src.rglob("*"), reverse=True):
        if d.is_dir() and not any(d.iterdir()):
            d.rmdir()
    print(f"Export done: {len(server)} docs on server, {written} written, {removed} removed.")


def diff_against_server(iris, src):
    changed, same = [], []
    for name, path in local_docs(src).items():
        server_lines = iris.get_doc(name)
        if server_lines is None or normalize(server_lines) != normalize(read_lines(path)):
            changed.append((name, path, "new" if server_lines is None else "modified"))
        else:
            same.append(name)
    return changed, same


def cmd_status(iris, src):
    changed, same = diff_against_server(iris, src)
    for name, _, kind in changed:
        print(f"  {kind:9} {name}")
    extra = sorted(set(iris.list_docs()) - set(local_docs(src)))
    for name in extra:
        print(f"  only-on-server {name}")
    print(f"{len(changed)} to deploy, {len(same)} unchanged, {len(extra)} only on server.")
    return changed


def cmd_import(iris, src, dry_run):
    changed = cmd_status(iris, src)
    if not changed:
        print("Nothing to deploy.")
        return
    if dry_run:
        print("Dry run - nothing uploaded.")
        return
    failed = False
    for name, path, _ in changed:
        errors = iris.put_doc(name, read_lines(path))
        if errors:
            failed = True
            print(f"  FAILED upload {name}: {errors}")
        else:
            print(f"  uploaded  {name}")
    names = [n for n, _, _ in changed]
    res = iris.compile(names)
    for line in res.get("console", []):
        if line.strip():
            print("  " + line)
    if res["status"].get("errors"):
        failed = True
        print(f"COMPILE ERRORS: {res['status']['errors']}")
    if failed:
        sys.exit("Deployment finished WITH ERRORS.")
    print(f"Deployment OK: {len(names)} docs uploaded and compiled.")


def load_env_file(start):
    """Load KEY=VALUE pairs from the nearest .env up the tree (does not override real env)."""
    for d in [start, *start.parents]:
        f = d / ".env"
        if f.is_file():
            for line in f.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
            return


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=["export", "import", "status"])
    p.add_argument("--workdir", default=".", help="git worktree containing src/ (default: cwd)")
    p.add_argument("--dry-run", action="store_true", help="import: only show what would change")
    args = p.parse_args()

    workdir = Path(args.workdir).resolve()
    load_env_file(workdir)
    missing = [v for v in ("IRIS_PORT", "IRIS_USER", "IRIS_PASS") if not os.environ.get(v)]
    if missing:
        sys.exit(f"ERROR: missing environment variables: {', '.join(missing)} (see .env.example)")

    iris = Iris(os.environ.get("IRIS_HOST", "localhost"), os.environ["IRIS_PORT"],
                os.environ.get("IRIS_NS", "USER"), os.environ["IRIS_USER"], os.environ["IRIS_PASS"])
    src = workdir / "src"
    src.mkdir(exist_ok=True)
    print(f"[{args.command}] {iris.base}  <->  {src}")

    if args.command == "export":
        cmd_export(iris, src)
    elif args.command == "status":
        cmd_status(iris, src)
    else:
        cmd_import(iris, src, args.dry_run)


if __name__ == "__main__":
    main()
