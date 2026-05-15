import os
import re
from unittest.mock import patch

import pytest
from wrd_sphinx_theme.sri import get_crossorigin
from wrd_sphinx_theme.sri import (
    compute_sri,
    compute_sri_hashlib,
    compute_sri_subprocess_openssl_dgst,
    compute_sri_subprocess_shasum,
)


def test_compute_sri(tmp_path):
    test_file = tmp_path / "test.txt"
    test_file.write_bytes(b"hello world")
    filename = str(test_file)

    # sha384 of "hello world"
    result = compute_sri_hashlib(filename)
    assert result.startswith("sha384-")
    assert len(result) > 20

    # Check subprocess version matches native python version
    result_sub = compute_sri_subprocess_openssl_dgst(filename)
    assert result == result_sub

    # Check shasum version matches natively
    result_shasum = compute_sri_subprocess_shasum(filename)
    assert result == result_shasum


def test_missing_file():
    assert compute_sri_hashlib("does_not_exist_file.txt") == ""
    assert compute_sri_subprocess_openssl_dgst("does_not_exist_file.txt") == ""
    assert compute_sri_subprocess_shasum("does_not_exist_file.txt") == ""


@pytest.mark.parametrize(
    "url, expected",
    [
        ("http://example.com/style.css", "anonymous"),
        ("https://example.com/script.js", "anonymous"),
        ("//cdn.example.com/library.js", "anonymous"),
        ("_static/css/local.css", ""),
        ("css/custom.css", ""),
        ("../relative/path.css", ""),
        ("/absolute/local/path.js", ""),
        ("file:///local/file.css", ""),
        (None, ""),
        ("", ""),
    ],
)
def test_get_crossorigin(url, expected):
    assert get_crossorigin(url) == expected


def test_compute_sri_is_cached(tmp_path):
    test_file = tmp_path / "test.txt"
    test_file.write_text("hello caching")
    filename = str(test_file)

    with patch("wrd_sphinx_theme.sri.compute_sri_hashlib") as mock_hashlib:
        mock_hashlib.return_value = "dummy-hash"

        # Call multiple times
        assert compute_sri(filename) == "dummy-hash"
        assert compute_sri(filename) == "dummy-hash"
        assert compute_sri(filename) == "dummy-hash"

        # It should only actually call the underlying hashlib once
        mock_hashlib.assert_called_once_with(filename, "sha384")


@pytest.fixture
def html_build_dir():
    build_dir = os.path.join(
        os.path.dirname(__file__),
        "..",
        "docs",
        "_build",
        "html",
    )
    build_dir = os.path.normpath(build_dir)
    if not os.path.exists(build_dir):
        raise Exception((build_dir, "does not exist"))
        # pytest.skip(f"Docs HTML build directory not found at {build_dir}. Build the docs first.")
    return build_dir


@pytest.mark.parametrize("html_file", [
    "index.html",
    "chats/CNT Bandgap Creation with Lignin Vitrimer .myst.html",
])
def test_sri_integrity_in_html_files(html_build_dir, html_file):
    html_path = os.path.join(html_build_dir, *html_file.split("/"))
    
    if not os.path.exists(html_path):
        raise Exception((html_path, "does not exist"))
        pytest.skip(f"HTML file not found at {html_path}. Build the docs first.")

    with open(html_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert 'integrity="sha384-' in content, (
        f"No valid sha384 SRI hashes found in {html_file}"
    )


@pytest.mark.parametrize("html_file", [
    "index.html",
    "chats/CNT Bandgap Creation with Lignin Vitrimer .chatexport_abc1.html",
])
def test_no_empty_integrity_attributes(html_build_dir, html_file):
    html_path = os.path.join(html_build_dir, *html_file.split("/"))
    
    if not os.path.exists(html_path):
        pytest.skip(f"HTML file not found at {html_path}. Build the docs first.")

    with open(html_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Check for boolean-style or malformed integrity attributes (e.g. `integrity ` without a value assignment)
    malformed_matches = re.findall(
        r"(?i)\bintegrity(?![a-zA-Z0-9_-])(?:\s+[^=]|\s*>)", content
    )
    assert not malformed_matches, (
        f"Found malformed integrity attributes without an equals sign in {html_file}: {malformed_matches}"
    )
