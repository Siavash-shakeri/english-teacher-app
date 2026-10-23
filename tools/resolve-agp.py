#!/usr/bin/env python3
"""Resolve full transitive dependency closure via POMs, download into a local Maven repo."""
import os, re, subprocess, sys
import xml.etree.ElementTree as ET

REPOS = [
    "https://dl.google.com/dl/android/maven2",
    "https://repo.maven.apache.org/maven2",
]
LOCAL = os.path.expanduser("~/workspace/english-teacher-app/m2repo")
NS = {"m": "http://maven.apache.org/POM/4.0.0"}

def gpath(group, name, version, fname):
    return f"{LOCAL}/{group.replace('.', '/')}/{name}/{version}/{fname}"

def curl(url, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    r = subprocess.run(["curl", "-sL", "--max-time", "60", "-o", out, "-w", "%{http_code}", url],
                       capture_output=True, text=True, timeout=90)
    code = r.stdout.strip()
    if code != "200" or not os.path.exists(out) or os.path.getsize(out) == 0:
        if os.path.exists(out): os.remove(out)
        return False
    return True

_pom_cache = {}
def fetch_pom(group, name, version):
    key = (group, name, version)
    if key in _pom_cache:
        return _pom_cache[key]
    gp = group.replace(".", "/")
    for repo in REPOS:
        url = f"{repo}/{gp}/{name}/{version}/{name}-{version}.pom"
        tmp = f"/var/tmp/poms/{gp}/{name}/{version}.pom"
        if curl(url, tmp):
            try:
                tree = ET.parse(tmp)
                _pom_cache[key] = tree.getroot()
                return tree.getroot()
            except Exception as e:
                print(f"  PARSE FAIL {url}: {e}", flush=True)
    _pom_cache[key] = None
    return None

def txt(el, tag):
    c = el.find(f"m:{tag}", NS)
    return c.text.strip() if c is not None and c.text else None

def substitute(s, props):
    def rep(m):
        return props.get(m.group(1), m.group(0))
    prev = None
    while prev != s:
        prev = s
        s = re.sub(r"\$\{([^}]+)\}", rep, s)
    return s

def collect_pom(group, name, version, seen_parents):
    root = fetch_pom(group, name, version)
    if root is None:
        print(f"MISSING POM {group}:{name}:{version}", flush=True)
        return None
    parent = root.find("m:parent", NS)
    packaging, pprops, pdepman, pdeps = "jar", {}, {}, []
    if parent is not None:
        pg, pn, pv = (txt(parent, "groupId"), txt(parent, "artifactId"), txt(parent, "version"))
        pkey = (pg, pn, pv)
        if pkey not in seen_parents:
            seen_parents.add(pkey)
            r = collect_pom(pg, pn, pv, seen_parents)
            if r: packaging, pprops, pdepman, pdeps = r
    myprops = dict(pprops)
    for pe in root.findall("m:properties/m:*", NS):
        tag = pe.tag.split("}")[1]
        if pe.text:
            myprops[tag] = pe.text.strip()
    myprops["project.groupId"] = txt(root, "groupId") or (parent is not None and txt(parent, "groupId")) or ""
    myprops["project.artifactId"] = txt(root, "artifactId") or ""
    myprops["project.version"] = txt(root, "version") or (parent is not None and txt(parent, "version")) or ""
    mydepman = dict(pdepman)
    for d in root.findall("m:dependencyManagement/m:dependencies/m:dependency", NS):
        dg, dn, dv = txt(d, "groupId"), txt(d, "artifactId"), txt(d, "version")
        scope = txt(d, "scope") or "compile"
        if dv and dg and dn:
            mydepman[(dg, dn)] = (dv, scope)
    pk = txt(root, "packaging")
    if pk: packaging = pk
    mydeps = list(pdeps)
    for d in root.findall("m:dependencies/m:dependency", NS):
        dg, dn, dv = txt(d, "groupId"), txt(d, "artifactId"), txt(d, "version")
        scope = txt(d, "scope")
        opt = txt(d, "optional") == "true"
        if not dg or not dn: continue
        if opt: continue
        if scope and scope not in ("compile", "runtime"): continue
        mydeps.append((dg, dn, dv, scope))
    return packaging, myprops, mydepman, mydeps

resolved = {}
artifacts = []

def resolve(g, n, v, stack=()):
    key = (g, n)
    if key in resolved:
        return
    if key in stack:
        print(f"  CYCLE {g}:{n}", flush=True); return
    r = collect_pom(g, n, v, set())
    if r is None:
        sys.exit(f"FATAL: cannot resolve {g}:{n}:{v}")
    packaging, props, depman, deps = r
    depman = {k: (substitute(x[0], props), x[1]) for k, x in depman.items()}
    final_deps = []
    for dg, dn, dv, scope in deps:
        dg, dn = substitute(dg, props), substitute(dn, props)
        mver, mscope = depman.get((dg, dn), (None, None))
        eff_scope = scope or mscope or "compile"
        if eff_scope not in ("compile", "runtime"):
            continue
        if dv:
            dv = substitute(dv, props)
        elif mver:
            dv = substitute(mver, props)
        else:
            sys.exit(f"FATAL: no version for {dg}:{dn} (needed by {g}:{n}:{v})")
        if dv.startswith("[") or "(" in dv:
            m = re.match(r"^\[([^\],\s]+)\]$", dv)
            if m:
                dv = m.group(1)  # pinned range like [1.7.0]
            else:
                sys.exit(f"FATAL: version range {dv} for {dg}:{dn}")
        final_deps.append((dg, dn, dv))
    resolved[key] = v
    artifacts.append((g, n, v, packaging if packaging != "bundle" else "jar"))
    for dg, dn, dv in final_deps:
        resolve(dg, dn, dv, stack + (key,))

def download(g, n, v, packaging):
    gp = g.replace(".", "/")
    base = f"{gp}/{n}/{v}/{n}-{v}"
    pom_path = gpath(g, n, v, f"{n}-{v}.pom")
    if not os.path.exists(pom_path):
        for repo in REPOS:
            if curl(f"{repo}/{base}.pom", pom_path): break
    if packaging == "pom":
        return
    art_path = gpath(g, n, v, f"{n}-{v}.{packaging}")
    if os.path.exists(art_path) and os.path.getsize(art_path) > 0:
        return
    for repo in REPOS:
        if curl(f"{repo}/{base}.{packaging}", art_path):
            print(f"  got {g}:{n}:{v}.{packaging} ({os.path.getsize(art_path)//1024}k)", flush=True)
            return
    print(f"  WARN no artifact {g}:{n}:{v}.{packaging}", flush=True)

if __name__ == "__main__":
    roots = [
        ("com.android.application", "com.android.application.gradle.plugin", "8.11.1"),
        ("com.android.tools.build", "gradle", "8.11.1"),
    ]
    for g, n, v in roots:
        print(f"resolving {g}:{n}:{v}", flush=True)
        resolve(g, n, v)
    print(f"\nTotal artifacts: {len(artifacts)}", flush=True)
    for g, n, v, p in artifacts:
        download(g, n, v, p)
    print("DONE", flush=True)
