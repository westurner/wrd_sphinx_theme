#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Tests for `wrd_sphinx_theme` package."""

import os
from types import SimpleNamespace

import pytest
import wrd_sphinx_theme


def test_theme_path():
    """Test that the theme template path exists."""
    assert os.path.exists(wrd_sphinx_theme.template_path)
    assert os.path.isdir(wrd_sphinx_theme.template_path)

def test_setup():
    """Test the setup function for Sphinx."""
    class DummyApp:
        def __init__(self):
            self.themes = {}
            self.connections = {}
        def add_html_theme(self, name, path):
            self.themes[name] = path
        def connect(self, event, callback):
            self.connections[event] = callback

    app = DummyApp()
    wrd_sphinx_theme.setup(app)
    assert 'wrd_sphinx_theme' in app.themes
    assert app.themes['wrd_sphinx_theme'] == wrd_sphinx_theme.template_path
    assert 'html-page-context' in app.connections


def test_update_context_filters_documentation_options_script_file():
    context = {
        'script_files': [
            SimpleNamespace(filename='documentation_options.js'),
            SimpleNamespace(filename='_static/js/jquery-3.7.1.min.js'),
            '_static/js/local.js',
        ],
        'css_files': [],
    }

    wrd_sphinx_theme.update_context(None, None, None, context, None)

    assert context['script_files'] == [
        '_static/js/jquery-3.7.1.min.js',
        '_static/js/local.js',
    ]


def test_sri_resolves_project_static_file(tmp_path):
    static_root = tmp_path / 'project-static'
    asset = static_root / 'img' / 'theme-test.png'
    asset.parent.mkdir(parents=True)
    asset.write_bytes(b'theme asset')

    app = SimpleNamespace(
        confdir=str(tmp_path),
        config=SimpleNamespace(html_static_path=['project-static']),
        builder=SimpleNamespace(outdir=str(tmp_path / 'out')),
    )
    context = {}
    wrd_sphinx_theme.add_sri_to_context(app, None, None, context, None)

    assert context['compute_sri']('_static/img/theme-test.png') == (
        wrd_sphinx_theme.compute_sri(str(asset))
    )

@pytest.fixture
def response():
    """Sample pytest fixture.

    See more at: http://doc.pytest.org/en/latest/fixture.html
    """
    # import requests
    # return requests.get('https://github.com/audreyr/cookiecutter-pypackage')


def test_content(response):
    """Sample pytest test function with the pytest fixture as an argument."""
    # from bs4 import BeautifulSoup
    # assert 'GitHub' in BeautifulSoup(response.content).title.string
