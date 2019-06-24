#!/usr/bin/env python3

import argparse
import json
import os
from datetime import datetime
from jinja2 import Environment, FileSystemLoader
from typing import NamedTuple
from urllib.error import URLError
from urllib.request import urlopen, Request

JDK_URLS = {
    (12, 0, 1): 'https://download.java.net/java/GA/jdk12.0.1/69cfe15208a647278a19ef0990eea691/12/GPL/openjdk-12.0.1_linux-x64_bin.tar.gz',
    (11, 0, 1): 'https://download.java.net/java/GA/jdk11/13/GPL/openjdk-11.0.1_linux-x64_bin.tar.gz'
}


class Version(NamedTuple):
    major: int
    minor: int
    hotfix: int

    @classmethod
    def parse(cls, s: str):
        return Version(*map(int, s.split('.', maxsplit=2)))

    def __str__(self) -> str:
        return f'{self.major}.{self.minor}.{self.hotfix}'


def latest_crash() -> Version:
    with urlopen('https://crate.io/versions.json') as r:
        d = json.load(r)
        return Version.parse(d['crash'])


def jdk_url_and_sha(jdk_version):
    if jdk_version not in JDK_URLS:
        raise ValueError(f'No URL for JDK version {jdk_version} found.')
    url = JDK_URLS[jdk_version]
    with urlopen(url + '.sha256') as r:
        sha256 = r.read().decode('utf-8')
    return url, sha256


def url_exists(url: str) -> bool:
    try:
        with urlopen(Request(url, method='HEAD')):
            return True
    except URLError:
        return False


def ensure_existing_crash(crash_version: Version) -> Version:
    if not crash_version:
        return latest_crash()
    url = f'https://cdn.crate.io/downloads/releases/crash_standalone_{crash_version}'
    if url_exists(url):
        return crash_version
    else:
        raise ValueError(f'No release found for crash {crash_version}')


def ensure_existing_cratedb(cratedb_version: Version) -> Version:
    url = f'https://cdn.crate.io/downloads/releases/crate-{cratedb_version}.tar.gz'
    if url_exists(url):
        return cratedb_version
    else:
        raise ValueError(f'No release found for CrateDB {cratedb_version}')


def find_template_for_version(cratedb_version: Version) -> str:
    v = cratedb_version
    versioned_template = f'Dockerfile_{v.major}.{v.minor}.j2'
    return versioned_template if os.path.exists(versioned_template) else 'Dockerfile.j2'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cratedb-version', type=Version.parse, required=True)
    parser.add_argument('--crash-version', type=Version.parse)
    parser.add_argument('--jdk-version', type=Version.parse)
    parser.add_argument('--template', type=str)
    args = parser.parse_args()

    cratedb_version = ensure_existing_cratedb(args.cratedb_version)
    jdk_version_default = Version(12, 0, 1) if cratedb_version.major >= 4 else Version(11, 0, 1)
    jdk_version = args.jdk_version or jdk_version_default
    jdk_url, jdk_sha256 = jdk_url_and_sha(jdk_version)
    template = args.template or find_template_for_version(cratedb_version)

    env = Environment(loader=FileSystemLoader(os.path.dirname(__file__)))
    template = env.get_template(template)
    print(template.render(
        CRATE_VERSION=ensure_existing_cratedb(args.cratedb_version),
        CRASH_VERSION=ensure_existing_crash(args.crash_version),
        JDK_VERSION=str(jdk_version),
        JDK_URL=jdk_url,
        JDK_SHA256=jdk_sha256,
        BUILD_TIMESTAMP=datetime.utcnow().isoformat()
    ))


if __name__ == "__main__":
    main()