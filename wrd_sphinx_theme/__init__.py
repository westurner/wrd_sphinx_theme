# -*- coding: utf-8 -*-

"""Top-level package for WRD Sphinx Theme."""

import os

__author__ = """@westurner"""
__email__ = 'wes@wrd.nu'
__version__ = '0.1.5'

package_dir = os.path.abspath(os.path.dirname(__file__))
template_path = os.path.join(package_dir, 'template')


def setup(app):
    app.add_html_theme('wrd_sphinx_theme', template_path)
