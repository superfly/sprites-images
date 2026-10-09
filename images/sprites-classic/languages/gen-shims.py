#!/usr/bin/env python3
"""Generates the mise-like shims for accessing each programming language
toolchain. Kept for compatibility.

Abandon hope, all ye who enter here.
"""

import sys
from pathlib import Path
from textwrap import indent

import tomllib

LANG_ENV = "/etc/profile.d/languages_env"
LANG_PATHS = "/etc/profile.d/languages_paths"


def load_spec() -> dict:
    try:
        spec = tomllib.load(sys.stdin.buffer)
    except tomllib.TOMLDecodeError as e:
        sys.exit(f"gen-shims: invalid spec: {e}")

    keys = {
        "name",
        "commands",
        "paths",
        "exec-overrides",
        "activator",
        "shim-persist-paths",
        "require-dirs",
        "env",
        "resolve",
    }
    if unknown := spec.keys() - keys:
        sys.exit(f"gen-shims: unknown spec keys: {', '.join(sorted(unknown))}")
    if unknown := spec.get("resolve", {}).keys() - {"shim", "bash", "fish"}:
        sys.exit(f"gen-shims: unknown resolve keys: {', '.join(sorted(unknown))}")
    for key in ("name", "commands", "paths"):
        if not spec.get(key):
            sys.exit(f"gen-shims: spec needs {key}")

    spec.setdefault("env", {})
    spec.setdefault("resolve", {})
    spec.setdefault("shim-persist-paths", True)
    spec.setdefault("require-dirs", False)
    spec.setdefault("exec-overrides", {})
    if unknown := spec["exec-overrides"].keys() - set(spec["commands"]):
        sys.exit(
            f"gen-shims: exec-overrides for unknown commands: {', '.join(sorted(unknown))}"
        )
    spec["activate"] = f"__{spec['name']}_activate"
    return spec


def resolve(spec: dict, shell: str) -> str:
    return spec["resolve"].get(shell, "").strip("\n")


def generate_shim(spec: dict, cmd: str) -> str:
    shim = """#!/bin/bash
set -e
"""

    if spec["env"]:
        shim += f'''
LANG_ENV="{LANG_ENV}"
[ -f "$LANG_ENV" ] || touch "$LANG_ENV"'''
        for var, default in spec["env"].items():
            shim += f'''
grep -q "^export {var}=" "$LANG_ENV" 2>/dev/null || \\
    echo 'export {var}="{default}"' >> "$LANG_ENV"'''
        shim += """
"""
        for var, default in spec["env"].items():
            shim += f'''
export {var}="${{{var}:-{default}}}"'''
        shim += """
"""
    if snippet := resolve(spec, "shim"):
        shim += f"""
{snippet}
"""
    for path in spec["paths"]:
        shim += f'''
case ":$PATH:" in
  *":{path}:"*) ;;
  *) export PATH="{path}:$PATH" ;;
esac'''
    shim += """
"""
    if spec["shim-persist-paths"]:
        shim += f'''
LANG_PATHS="{LANG_PATHS}"'''
        for path in spec["paths"]:
            shim += f'''
grep -qxF "{path}" "$LANG_PATHS" 2>/dev/null || \\
    echo "{path}" >> "$LANG_PATHS" 2>/dev/null || true'''
        shim += """
"""
    shim += f'''
exec "{spec["exec-overrides"].get(cmd, spec["paths"][0])}/$(basename "$0")" "$@"
'''

    return shim


def generate_bash(spec: dict) -> str:
    bash = f"{spec['activate']}() {{"
    for var, default in spec["env"].items():
        bash += f'''
    export {var}="${{{var}:-{default}}}"'''
    if snippet := resolve(spec, "bash"):
        bash += f"""
{indent(snippet, "    ")}"""

    persist = ""
    for path in spec["paths"]:
        persist += f'''
    case ":$PATH:" in
        *":{path}:"*) ;;
        *) export PATH="{path}:$PATH" ;;
    esac'''
    if spec["env"]:
        persist += f'''
    local LANG_ENV="{LANG_ENV}"'''
        for var in spec["env"]:
            persist += f"""
    grep -q "^export {var}=" "$LANG_ENV" 2>/dev/null || \\
        echo "export {var}=\\"${var}\\"" >> "$LANG_ENV" 2>/dev/null || true"""
    persist += f'''
    local LANG_PATHS="{LANG_PATHS}"'''
    for path in spec["paths"]:
        persist += f'''
    grep -qxF "{path}" "$LANG_PATHS" 2>/dev/null || \\
        echo "{path}" >> "$LANG_PATHS" 2>/dev/null || true'''
    if spec["require-dirs"]:
        bash += f"""
    if {" && ".join(f'[ -d "{path}" ]' for path in spec["paths"])}; then{indent(persist, "    ")}
    fi"""
    else:
        bash += persist

    bash += f"""
    unset -f {" ".join(spec["commands"])} {spec["activate"]} 2>/dev/null
}}"""
    for cmd in spec["commands"]:
        bash += f"""
{cmd}() {{ {spec["activate"]}; command {cmd} "$@"; }}"""
    bash += """
"""

    return bash


def generate_fish(spec: dict) -> str:
    fish = f'function {spec["activate"]} --description "Activate {spec["name"]} environment"'
    for var, default in spec["env"].items():
        fish += f'''
    set -gx {var} (test -n "${var}"; and echo ${var}; or echo "{default}")'''
    if snippet := resolve(spec, "fish"):
        fish += f"""
{indent(snippet, "    ")}"""

    persist = ""
    for path in spec["paths"]:
        persist += f"""
    if not contains {path} $PATH
        set -gx PATH {path} $PATH
    end"""
    if spec["env"]:
        persist += f'''
    set -l LANG_ENV "{LANG_ENV}"'''
        for var in spec["env"]:
            persist += f"""
    grep -q "^export {var}=" "$LANG_ENV" 2>/dev/null; or echo "export {var}=\\"${var}\\"" >> "$LANG_ENV" 2>/dev/null; or true"""
    persist += f'''
    set -l LANG_PATHS "{LANG_PATHS}"'''
    for path in spec["paths"]:
        persist += f'''
    grep -qxF "{path}" "$LANG_PATHS" 2>/dev/null; or echo "{path}" >> "$LANG_PATHS" 2>/dev/null; or true'''
    if spec["require-dirs"]:
        fish += f"""
    if {"; and ".join(f'test -d "{path}"' for path in spec["paths"])}{indent(persist, "    ")}
    end"""
    else:
        fish += persist

    fish += f"""
    functions -e {" ".join(spec["commands"])} {spec["activate"]}
end"""
    for cmd in spec["commands"]:
        fish += f'''
function {cmd} --description "{cmd} with {spec["name"]} activation"
    {spec["activate"]}
    command {cmd} $argv
end'''
    fish += """
"""

    return fish


def generate_bash_chain(spec: dict) -> str:
    activator, probe = spec["activator"].split(" ", 1)

    bash = f"""{activator}() {{
{indent(resolve(spec, "bash"), "    ")}
    unset -f {" ".join(spec["commands"])} 2>/dev/null
    command {activator} "$@"
}}"""
    for cmd in spec["commands"]:
        if cmd != activator:
            bash += f"""
{cmd}() {{ {activator} {probe} >/dev/null 2>&1; unset -f {cmd} 2>/dev/null; command {cmd} "$@"; }}"""
    bash += """
"""

    return bash


def generate_fish_chain(spec: dict) -> str:
    activator, probe = spec["activator"].split(" ", 1)

    fish = f'''function {activator} --description "{activator} with {spec["name"]} activation"
{indent(resolve(spec, "fish"), "    ")}
    functions -e {" ".join(spec["commands"])}
    command {activator} $argv
end'''
    for cmd in spec["commands"]:
        if cmd != activator:
            fish += f'''
function {cmd} --description "{cmd} with {spec["name"]} activation"
    {activator} {probe} >/dev/null 2>&1
    functions -e {cmd}
    command {cmd} $argv
end'''
    fish += """
"""

    return fish


def main() -> None:
    spec = load_spec()
    name = spec["name"]
    bin_dir = Path("/.sprite/bin")
    functions_dir = Path("/.sprite/languages/shells/functions")

    bin_dir.mkdir(parents=True, exist_ok=True)
    for cmd in spec["commands"]:
        (bin_dir / cmd).write_text(generate_shim(spec, cmd))
        (bin_dir / cmd).chmod(0o755)

    if "activator" in spec:
        bash, fish = generate_bash_chain(spec), generate_fish_chain(spec)
    else:
        bash, fish = generate_bash(spec), generate_fish(spec)
    for shell, content in (("bash", bash), ("zsh", bash), ("fish", fish)):
        (functions_dir / shell).mkdir(parents=True, exist_ok=True)
        (functions_dir / shell / f"{name}.{shell}").write_text(content)

    print(f"gen-shims: {name} -> {' '.join(spec['commands'])}")


if __name__ == "__main__":
    main()
