

"use strict";

function navbar_scrollto(node) {
    var sidebar = $('#sidebar-wrapper').first()[0];
    if (!sidebar) return;

    var navbar = $(sidebar).find('div.sidebar').first()[0];
    var $node = $(node).first();
    if (!navbar || !$node.length || !document.documentElement.contains($node[0])) return;
    if (!$node.offset() || !$(navbar).is(':visible')) return;
    if (typeof $.fn.scrollTo !== 'function' || typeof $.fn.isOnScreen !== 'function') return;

    if (!$node.isOnScreen()) {
        $(sidebar).scrollTo($node, {
            axis: 'y',
            offset: { top: -100 }
        });
    }
}
function navbar_update(nodeurl) {

    // console.log('navbar_update', nodeurl);

    if (typeof nodeurl !== 'string' || nodeurl.length < 2 || nodeurl.charAt(0) !== '#') {
        return;
    }
    if (nodeurl.match('^#index-[0-9]+')) {
        return;
    }
    var targetId;
    try {
        targetId = decodeURIComponent(nodeurl.slice(1));
    } catch (error) {
        return;
    }
    if (!document.getElementById(targetId)) return;

    var content = $('#content-wrapper');
    var navbar = $('#sidebar-wrapper').find('div.sidebar').first()[0];
    ($(content)
        .find('a.headerlink.youarehere')
        .removeClass('youarehere')
        .text('¶')
    );
    ($('#navbar-top')
        .find('a.youarehere')
        .removeClass('youarehere')
    );
    ($('#navbar-top')
        .find('li.youarehere')
        .removeClass('youarehere')
    );
    var selectedlink = $(navbar)
        .find('a.youarehere');
    selectedlink
        .removeClass('youarehere');
    selectedlink.parent()
        .removeClass('youarehere');

    if (nodeurl) {
        var headerlink = $(content).find('a.headerlink').filter(function() {
            return this.hash === nodeurl;
        });
        headerlink
            .addClass('youarehere')
            .text('⬅');
        headerlink.parent()
            .addClass('youarehere');

        var toplink = $('#navbar-top')
            .find('a.reference.internal').filter(function() {
                return this.hash === nodeurl;
            });
        toplink
            .addClass('youarehere');
        toplink.parent()
            .addClass('youarehere');

        var navbarlink = $(navbar)
            .find('a').filter(function() {
                return this.hash === nodeurl;
            }).first();

        if (navbarlink.length) {
            navbarlink
                .addClass('youarehere');
            navbarlink.parent()
                .addClass('youarehere');
            // console.log(navbarlink);
            try {
                navbar_scrollto(navbarlink.first()); // # navbar a.youarehere
            } catch(e) {
               
                console.log('navbar_scrollto(navbarlink.first()): err');
                console.log(e);
            }
        } else {
            console.log("nodeurl not found");
            console.log(nodeurl);
        }
    } else {
        console.log("nodeurl is false");
        console.log(nodeurl);
    }
}

function navbar__remap_sphinx_toc_links() {
    var content = $('#content-wrapper');
    ($(content)
        .find('a.headerlink')
        .map(function(i, node) {
            // console.log(i, node);
            $(node.previousSibling).attr('href', $(node).attr('href'));
        })
    );
}

function navbar__add_top_button() {
    ($('<button type="button" class="toplink navbar-toggle"><a href="#" title="Top"><span>^</span></a></button>')
     .appendTo('body'));
}

function navbar_init() {
    // require('jquery.scrollto')
    //var scriptstr = '<script src="https://cdn.jsdelivr.net/jquery.scrollto/2.1.0/jquery.scrollTo.min.js"></script>';
    //$(scriptstr).appendTo("head");
    navbar_update(window.location.hash);

    navbar__remap_sphinx_toc_links();
    navbar__add_top_button();

    function _updatenavbar(hash) {
        // console.log(e); // e.newURL , e.oldURL
        var loc_hash_url = hash || window.location.hash;
        // console.log(loc_hash_url);
        if (loc_hash_url != false) {
            navbar_update(loc_hash_url);
        };
    }

    window.addEventListener('hashchange', function(e) {
        _updatenavbar();
    }, false);

    document.addEventListener('click', function(e) {
        var e = window.e || e;
        if (e.target.tagName !== 'A') {
            return
        }
        // TODO: skip extra-page links
        // a.headerlink
        // a.internal
        _updatenavbar(e.target.hash);
    }, false);
}


$(document).ready(navbar_init);

