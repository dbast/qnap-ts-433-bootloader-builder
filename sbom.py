#!/usr/bin/env python3
"""Regenerate the static CycloneDX SBOM from pinned submodules."""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import NoReturn

OUTPUT = Path("sbom.cdx.json")
COMPONENTS = [
    {
        "path": "u-boot",
        "bom-ref": "u-boot",
        "name": "u-boot",
        "cpe": "cpe:2.3:a:denx:u-boot:{version}:*:*:*:*:*:*:*",
        "purl": "pkg:github/u-boot/u-boot@v{version}",
    },
    {
        "path": "trusted-firmware-a",
        "bom-ref": "trusted-firmware-a",
        "name": "trusted-firmware-a",
        "cpe": "cpe:2.3:o:trustedfirmware:trusted_firmware-a:{version}:*:*:*:*:*:*:*",
        "purl": "pkg:github/TrustedFirmware-A/trusted-firmware-a@v{version}",
    },
    {
        "path": "rkbin",
        "bom-ref": "rkbin-ddr",
        "name": None,
        "purl": "pkg:github/rockchip-linux/rkbin@{commit}#bin/rk35/{name}",
    },
]


def fail(message: str) -> NoReturn:
    sys.exit(f"sbom.py: {message}")


def makefile_var(path, name):
    try:
        content = Path(path).read_text()
    except FileNotFoundError:
        fail(f"missing {path}; initialize the submodules first")
    match = re.search(rf"^{name}\s*[:?]?=\s*(\S+)\s*$", content, re.MULTILINE)
    if not match:
        fail(f"cannot read {name} from {path}")
    return match.group(1)


def submodule_commit(path):
    if not (Path(path) / ".git").exists():
        fail(f"submodule {path} is not initialized")
    staged = subprocess.run(
        ["git", "ls-files", "--stage", "--", path],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    if len(staged) < 2 or staged[0] != "160000":
        fail(f"cannot read gitlink for {path}")
    checked_out = subprocess.run(
        ["git", "-C", path, "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if checked_out != staged[1]:
        fail(f"submodule {path} checkout does not match its staged gitlink")
    return checked_out


def versions():
    ddr_name = makefile_var("Makefile", "DDR_BIN")
    match = re.fullmatch(r"rk3568_ddr_1560MHz_v(.+)\.bin", ddr_name)
    if not match:
        fail(f"cannot derive rkbin version from {ddr_name}")
    return {
        "u-boot": ".".join(
            makefile_var("u-boot/Makefile", part) for part in ("VERSION", "PATCHLEVEL")
        ),
        "trusted-firmware-a": ".".join(
            makefile_var("trusted-firmware-a/Makefile", f"VERSION_{part}")
            for part in ("MAJOR", "MINOR", "PATCH")
        ),
        "rkbin": match.group(1),
        "rkbin-name": ddr_name,
    }


def main():
    component_versions = versions()
    components = []
    for spec in COMPONENTS:
        version = component_versions[spec["path"]]
        name = spec["name"] or component_versions["rkbin-name"]
        commit = submodule_commit(spec["path"])
        component = {
            "bom-ref": spec["bom-ref"],
            "type": "library",
            "name": name,
            "version": version,
            "purl": spec["purl"].format(name=name, version=version, commit=commit),
            "properties": [{"name": "git:commit", "value": commit}],
        }
        if cpe := spec.get("cpe"):
            component["cpe"] = cpe.format(version=version)
        components.append(component)

    bom = {
        "$schema": "https://cyclonedx.org/schema/bom-1.6.schema.json",
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "components": components,
    }

    assert all(component["version"] for component in components)
    assert any("cpe" in component for component in components)
    OUTPUT.write_text(json.dumps(bom, indent=2) + "\n")


if __name__ == "__main__":
    main()
