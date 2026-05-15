"""
"""
import sys
import hashlib
import base64
import binascii
import mmap
import os
import re
import subprocess
import functools

HAS_FILE_DIGEST = sys.version_info >= (3, 11)

try:
    from sphinx.util import logging
    logger = logging.getLogger(__name__)
except ImportError:
    import logging
    logger = logging.getLogger(__name__)

if HAS_FILE_DIGEST:
    def _hash_file(f, algo: str):
        return hashlib.file_digest(f, algo)
else:
    def _hash_file(f, algo: str):
        h = hashlib.new(algo)
        try:
            fd = f.fileno()
            size = os.fstat(fd).st_size
            if size > 0:
                with mmap.mmap(fd, size, access=mmap.ACCESS_READ) as mm:
                    h.update(mm)
                return h
        except (AttributeError, ValueError, OSError):
            pass
        
        # Fallback for empty files or non-mmap-able streams
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
        return h

def compute_sri_hashlib(file_path: str, algo: str = "sha384") -> str:
    """Compute the Subresource Integrity (SRI) hash for a file using hashlib."""
    if not os.path.isfile(file_path):
        logger.warning(f"SRI computation skipped: not a valid file path: '{file_path}'")
        return ""
    with open(file_path, "rb") as f:
        h = _hash_file(f, algo)
    digest = binascii.b2a_base64(h.digest(), newline=False).decode("ascii")
    return f"{algo}-{digest}"


def compute_sri_subprocess_openssl_dgst(file_path: str, algo: str = "sha384") -> str:
    """Compute the Subresource Integrity (SRI) hash using openssl via subprocess safely."""
    if not os.path.isfile(file_path):
        logger.warning(f"SRI computation skipped: not a valid file path: '{file_path}'")
        return ""
    try:
        openssl_proc = subprocess.Popen(
            ['openssl', 'dgst', f'-{algo}', '-binary', file_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        try:
            base64_proc = subprocess.Popen(
                ['base64'],
                stdin=openssl_proc.stdout,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL
            )
        finally:
            if openssl_proc.stdout:
                openssl_proc.stdout.close()
        
        out, _ = base64_proc.communicate()
        if base64_proc.returncode != 0 or openssl_proc.wait() != 0:
            return ""
        digest = out.decode('utf-8').strip()
        return f"{algo}-{digest}"
    except Exception:
        return ""


def compute_sri_subprocess_shasum(file_path: str, algo: str = "sha384") -> str:
    """Compute the Subresource Integrity (SRI) hash using shasum utilities via subprocess safely."""
    if not os.path.isfile(file_path):
        logger.warning(f"SRI computation skipped: not a valid file path: '{file_path}'")
        return ""
    try:
        result = subprocess.run(
            [f'{algo}sum', file_path],
            capture_output=True,
            text=True,
            check=True
        )
        hex_digest = result.stdout.split()[0]
        bin_digest = bytes.fromhex(hex_digest)
        digest = base64.b64encode(bin_digest).decode('utf-8')
        return f"{algo}-{digest}"
    except Exception:
        return ""


@functools.lru_cache()
def get_crossorigin(url: str) -> str:
    """
    Return 'anonymous' if the URL appears to be an absolute (external) URL.
    Returns an empty string for local paths.
    """
    if url and re.match(r'^(https?:)?//', str(url), re.IGNORECASE):
        return "anonymous"
    return ""


@functools.lru_cache()
def compute_sri(file_path: str, algo: str = "sha384") -> str:
    """Cached wrapper for SRI computation."""
    return compute_sri_hashlib(file_path, algo)


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        for p in sys.argv[1:]:
            print(f"{p}: {compute_sri_hashlib(p)}")
