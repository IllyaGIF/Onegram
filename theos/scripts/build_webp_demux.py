import os

from bootstrap_build import download, safe_unpack, validate_sha256
from build_pst import build_pst


WEBP_URL = 'https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-0.4.3.tar.gz'
WEBP_SHA256 = 'efbe0d58fda936f2ed99d0b837ed7087d064d6838931f282c4618d2a3f7390c4'


def plugins_enabled():
    return os.environ.get('ONEGRAM_PLUGINS', '1') == '1'


def build_webp_demux(out, compiler, libtool, lipo, architecture):
    sources = out / 'dependency-sources'
    sources.mkdir(parents=True, exist_ok=True)
    archive = sources / 'libwebp-0.4.3.tar.gz'
    if not archive.is_file():
        download(WEBP_URL, archive)
    validate_sha256(archive, WEBP_SHA256)
    root = sources / 'libwebp-0.4.3'
    source = root / 'src' / 'demux' / 'demux.c'
    if not source.is_file():
        safe_unpack(archive, sources)
    headers = sorted((root / 'src' / 'webp').glob('*.h')) + [root / 'src' / 'utils' / 'utils.h']
    products = out / 'products'
    products.mkdir(parents=True, exist_ok=True)
    build_pst([source], compiler + ['-std=gnu99', '-Os', '-Wno-everything'], libtool, lipo, architecture,
              products / 'libwebpdemux.a', out / ('webp-demux-' + architecture), headers)
