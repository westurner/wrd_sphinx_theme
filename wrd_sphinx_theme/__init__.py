"""Top-level package for WRD Sphinx Theme."""

import hashlib
import os

from .sri import compute_sri, get_crossorigin

#from .sri import compute_sri_hashlib, compute_sri_shasum, compute_sri_subprocess_openssl_dgst

# __author__ = "@westurner"
# __email__ = "wes@wrd.nu"
__version__ = '0.1.6'

package_dir = os.path.abspath(os.path.dirname(__file__))
package_template_path = os.path.join(package_dir, 'template')

# Sphinx StandaloneHTMLBuilder._static_dir is hardcoded to '_static/'
SPHINX_STATIC_URL_PREFIX = '_static/'


def sri_asset_fingerprint(app):
    """Return a signature of theme and project CSS/JS paths, sizes, and mtimes."""
    roots = [os.path.join(package_template_path, 'static')]
    roots.extend(
        os.path.abspath(os.path.join(app.confdir, static_path))
        for static_path in app.config.html_static_path
    )
    entries = []
    for root in roots:
        if not os.path.isdir(root):
            continue
        for current, directories, filenames in os.walk(root):
            directories.sort()
            for filename in sorted(filenames):
                if not filename.endswith(('.css', '.js')):
                    continue
                filepath = os.path.join(current, filename)
                try:
                    stat = os.stat(filepath)
                except OSError:
                    continue
                entries.append(
                    (root, os.path.relpath(filepath, root), stat.st_size, stat.st_mtime_ns)
                )

    digest = hashlib.sha256()
    for entry in sorted(entries):
        digest.update(repr(entry).encode('utf-8'))
        digest.update(b'\n')
    return digest.hexdigest()


def invalidate_docs_for_sri_asset_changes(app, env, added, changed, removed):
    """Mark every document outdated when the SRI asset signature changes."""
    signature = sri_asset_fingerprint(app)
    marker = os.path.join(app.doctreedir, 'wrd_sphinx_theme_sri_assets.sha256')
    try:
        with open(marker, encoding='utf-8') as marker_file:
            previous = marker_file.read().strip()
    except OSError:
        previous = None

    app._wrd_sphinx_theme_sri_signature = signature
    if previous != signature:
        return env.found_docs
    return ()


def persist_sri_asset_fingerprint(app, exception) -> None: 
    """Store the current asset signature after a successful Sphinx build."""
    if exception is not None:
        return
    signature = getattr(app, '_wrd_sphinx_theme_sri_signature', None)
    if signature is None:
        return

    os.makedirs(app.doctreedir, exist_ok=True)
    marker = os.path.join(app.doctreedir, 'wrd_sphinx_theme_sri_assets.sha256')
    with open(marker, 'w', encoding='utf-8') as marker_file:
        marker_file.write(signature + '\n')


def add_compute_sri_and_get_crossorigin(
    app, pagename, templatename, context, doctree):
    """Expose SRI helpers and map Sphinx static URLs back to source files.

    Sphinx's HTML builder uses the fixed ``_static/`` URL prefix; the
    ``html_static_path`` setting provides the project source directories to
    search beneath ``confdir``.
    """
    static_dirs = getattr(app, '_wrd_theme_static_dirs', None)
    if static_dirs is None:
        static_dirs = tuple(
            os.path.join(app.confdir, static_path)
            for static_path in app.config.html_static_path
        )
        app._wrd_theme_static_dirs = static_dirs

    def get_sri(filename):
        """Resolve an asset URL, record its source dependency, and return its SRI."""
        if hasattr(filename, 'filename'):
            filename = filename.filename

        filename = str(filename)
        filepath = str(os.path.join(app.builder.outdir, filename))
        source_filepath = None
        if filename.startswith(SPHINX_STATIC_URL_PREFIX):
            relative = filename[len(SPHINX_STATIC_URL_PREFIX):]
            theme_filepath = os.path.join(package_template_path, 'static', relative)
            if os.path.exists(theme_filepath):
                source_filepath = theme_filepath
            else:
                for static_dir in static_dirs:
                    proj_filepath = os.path.join(static_dir, relative)
                    if os.path.exists(proj_filepath):
                        source_filepath = proj_filepath
                        break

        if source_filepath:
            if not os.path.exists(filepath):
                filepath = source_filepath
            if pagename and hasattr(app, 'env'):
                app.env.note_dependency(source_filepath, docname=pagename)

        return compute_sri(filepath)
        #return compute_sri_hashlib(filepath)
        #return compute_sri_openssl_dgst(filepath)
        #return compute_sri_shasum(filepath)

    context['compute_sri'] = get_sri
    context['get_crossorigin'] = get_crossorigin


def add_css_files_and_script_files(app, pagename, templatename, context, doctree) -> None:
    """Normalize CSS paths while preserving script asset attributes.

    Since Sphinx 7.2, script entries may be ``_JavaScript`` objects with
    attributes such as ``type="module"``. Keep those objects intact for the
    SRI template to render.

    Also removes the autogenerated
    ``documentation_options.js`` entry because that file is Sphinx plumbing,
    not a user asset that should be included in the theme context asset list.
    """
    css_items = context.get('css_files')
    if css_items:
        css = []
        for item in css_items:
            filename = getattr(item, 'filename', None)
            if filename is not None:
                css.append(filename)
            else:
                css.append(str(item))
        context['css_files'] = css

    script_items = context.get('script_files')
    if script_items:
        scripts = []
        for item in script_items:
            filename = getattr(item, 'filename', item)
            if os.path.basename(str(filename)) != 'documentation_options.js':
                scripts.append(item)
        context['script_files'] = [
            item for item in scripts
        ]


def setup(app) -> dict:
    """Register the theme and its Sphinx page, environment, and build hooks."""
    app.add_html_theme('wrd_sphinx_theme', package_template_path)
    app.connect('html-page-context', add_css_files_and_script_files)
    app.connect('html-page-context', add_compute_sri_and_get_crossorigin)
    app.connect('env-get-outdated', invalidate_docs_for_sri_asset_changes)
    app.connect('build-finished', persist_sri_asset_fingerprint)
    return {'version': __version__, 'env_version': 1}

