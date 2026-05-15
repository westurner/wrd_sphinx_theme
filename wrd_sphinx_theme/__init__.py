# -*- coding: utf-8 -*-

"""Top-level package for WRD Sphinx Theme."""

import os
from .sri import get_crossorigin, compute_sri
#from .sri import compute_sri_hashlib, compute_sri_shasum, compute_sri_subprocess_openssl_dgst, compute_sri

# __author__ = "@westurner"
# __email__ = "wes@wrd.nu"
__version__ = '0.1.6'

package_dir = os.path.abspath(os.path.dirname(__file__))
template_path = os.path.join(package_dir, 'template')


def add_sri_to_context(app, pagename, templatename, context, doctree):
    def get_sri(filename):
        if hasattr(filename, 'filename'):
            filename = filename.filename
            
        filename = str(filename)
            
        filepath = str(os.path.join(app.builder.outdir, filename))
        if not os.path.exists(filepath):
            if filename.startswith('_static/'):
                theme_filepath = os.path.join(template_path, 'static', filename[len('_static/'):])
                if os.path.exists(theme_filepath):
                    filepath = theme_filepath
                else:
                    # check project static dirs
                    for static_path in app.config.html_static_path:
                        proj_filepath = os.path.join(app.confdir, static_path, filename[len('_static/'):])
                        if os.path.exists(proj_filepath):
                            filepath = proj_filepath
                            break

        return compute_sri(filepath)
        #return compute_sri_hashlib(filepath)
        #return compute_sri_openssl_dgst(filepath)
        #return compute_sri_shasum(filepath)

    context['compute_sri'] = get_sri
    context['get_crossorigin'] = get_crossorigin


def update_context(app, pagename, templatename, context, doctree):
    for key in ['css_files', 'script_files']:
        if key in context and context[key]:
            # Convert object to string for basicstrap which expects plain strings
            new_list = []
            for item in context[key]:
                if hasattr(item, 'filename'):
                    new_list.append(item.filename)
                else:
                    new_list.append(str(item))
            context[key] = new_list


def setup(app):
    app.add_html_theme('wrd_sphinx_theme', template_path)
    app.connect('html-page-context', update_context)
    app.connect('html-page-context', add_sri_to_context)
