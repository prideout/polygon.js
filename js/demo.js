var require = function (file, cwd) {
    var resolved = require.resolve(file, cwd || '/');
    var mod = require.modules[resolved];
    if (!mod) throw new Error(
        'Failed to resolve module ' + file + ', tried ' + resolved
    );
    var res = mod._cached ? mod._cached : mod();
    return res;
}

require.paths = [];
require.modules = {};
require.extensions = [".js",".coffee"];

require._core = {
    'assert': true,
    'events': true,
    'fs': true,
    'path': true,
    'vm': true
};

require.resolve = (function () {
    return function (x, cwd) {
        if (!cwd) cwd = '/';
        
        if (require._core[x]) return x;
        var path = require.modules.path();
        cwd = path.resolve('/', cwd);
        var y = cwd || '/';
        
        if (x.match(/^(?:\.\.?\/|\/)/)) {
            var m = loadAsFileSync(path.resolve(y, x))
                || loadAsDirectorySync(path.resolve(y, x));
            if (m) return m;
        }
        
        var n = loadNodeModulesSync(x, y);
        if (n) return n;
        
        throw new Error("Cannot find module '" + x + "'");
        
        function loadAsFileSync (x) {
            if (require.modules[x]) {
                return x;
            }
            
            for (var i = 0; i < require.extensions.length; i++) {
                var ext = require.extensions[i];
                if (require.modules[x + ext]) return x + ext;
            }
        }
        
        function loadAsDirectorySync (x) {
            x = x.replace(/\/+$/, '');
            var pkgfile = x + '/package.json';
            if (require.modules[pkgfile]) {
                var pkg = require.modules[pkgfile]();
                var b = pkg.browserify;
                if (typeof b === 'object' && b.main) {
                    var m = loadAsFileSync(path.resolve(x, b.main));
                    if (m) return m;
                }
                else if (typeof b === 'string') {
                    var m = loadAsFileSync(path.resolve(x, b));
                    if (m) return m;
                }
                else if (pkg.main) {
                    var m = loadAsFileSync(path.resolve(x, pkg.main));
                    if (m) return m;
                }
            }
            
            return loadAsFileSync(x + '/index');
        }
        
        function loadNodeModulesSync (x, start) {
            var dirs = nodeModulesPathsSync(start);
            for (var i = 0; i < dirs.length; i++) {
                var dir = dirs[i];
                var m = loadAsFileSync(dir + '/' + x);
                if (m) return m;
                var n = loadAsDirectorySync(dir + '/' + x);
                if (n) return n;
            }
            
            var m = loadAsFileSync(x);
            if (m) return m;
        }
        
        function nodeModulesPathsSync (start) {
            var parts;
            if (start === '/') parts = [ '' ];
            else parts = path.normalize(start).split('/');
            
            var dirs = [];
            for (var i = parts.length - 1; i >= 0; i--) {
                if (parts[i] === 'node_modules') continue;
                var dir = parts.slice(0, i + 1).join('/') + '/node_modules';
                dirs.push(dir);
            }
            
            return dirs;
        }
    };
})();

require.alias = function (from, to) {
    var path = require.modules.path();
    var res = null;
    try {
        res = require.resolve(from + '/package.json', '/');
    }
    catch (err) {
        res = require.resolve(from, '/');
    }
    var basedir = path.dirname(res);
    
    var keys = (Object.keys || function (obj) {
        var res = [];
        for (var key in obj) res.push(key)
        return res;
    })(require.modules);
    
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        if (key.slice(0, basedir.length + 1) === basedir + '/') {
            var f = key.slice(basedir.length);
            require.modules[to + f] = require.modules[basedir + f];
        }
        else if (key === basedir) {
            require.modules[to] = require.modules[basedir];
        }
    }
};

require.define = function (filename, fn) {
    var dirname = require._core[filename]
        ? ''
        : require.modules.path().dirname(filename)
    ;
    
    var require_ = function (file) {
        return require(file, dirname)
    };
    require_.resolve = function (name) {
        return require.resolve(name, dirname);
    };
    require_.modules = require.modules;
    require_.define = require.define;
    var module_ = { exports : {} };
    
    require.modules[filename] = function () {
        require.modules[filename]._cached = module_.exports;
        fn.call(
            module_.exports,
            require_,
            module_,
            module_.exports,
            dirname,
            filename
        );
        require.modules[filename]._cached = module_.exports;
        return module_.exports;
    };
};

if (typeof process === 'undefined') process = {};

if (!process.nextTick) process.nextTick = (function () {
    var queue = [];
    var canPost = typeof window !== 'undefined'
        && window.postMessage && window.addEventListener
    ;
    
    if (canPost) {
        window.addEventListener('message', function (ev) {
            if (ev.source === window && ev.data === 'browserify-tick') {
                ev.stopPropagation();
                if (queue.length > 0) {
                    var fn = queue.shift();
                    fn();
                }
            }
        }, true);
    }
    
    return function (fn) {
        if (canPost) {
            queue.push(fn);
            window.postMessage('browserify-tick', '*');
        }
        else setTimeout(fn, 0);
    };
})();

if (!process.title) process.title = 'browser';

if (!process.binding) process.binding = function (name) {
    if (name === 'evals') return require('vm')
    else throw new Error('No such module')
};

if (!process.cwd) process.cwd = function () { return '.' };

if (!process.env) process.env = {};
if (!process.argv) process.argv = [];

require.define("path", function (require, module, exports, __dirname, __filename) {
function filter (xs, fn) {
    var res = [];
    for (var i = 0; i < xs.length; i++) {
        if (fn(xs[i], i, xs)) res.push(xs[i]);
    }
    return res;
}

// resolves . and .. elements in a path array with directory names there
// must be no slashes, empty elements, or device names (c:\) in the array
// (so also no leading and trailing slashes - it does not distinguish
// relative and absolute paths)
function normalizeArray(parts, allowAboveRoot) {
  // if the path tries to go above the root, `up` ends up > 0
  var up = 0;
  for (var i = parts.length; i >= 0; i--) {
    var last = parts[i];
    if (last == '.') {
      parts.splice(i, 1);
    } else if (last === '..') {
      parts.splice(i, 1);
      up++;
    } else if (up) {
      parts.splice(i, 1);
      up--;
    }
  }

  // if the path is allowed to go above the root, restore leading ..s
  if (allowAboveRoot) {
    for (; up--; up) {
      parts.unshift('..');
    }
  }

  return parts;
}

// Regex to split a filename into [*, dir, basename, ext]
// posix version
var splitPathRe = /^(.+\/(?!$)|\/)?((?:.+?)?(\.[^.]*)?)$/;

// path.resolve([from ...], to)
// posix version
exports.resolve = function() {
var resolvedPath = '',
    resolvedAbsolute = false;

for (var i = arguments.length; i >= -1 && !resolvedAbsolute; i--) {
  var path = (i >= 0)
      ? arguments[i]
      : process.cwd();

  // Skip empty and invalid entries
  if (typeof path !== 'string' || !path) {
    continue;
  }

  resolvedPath = path + '/' + resolvedPath;
  resolvedAbsolute = path.charAt(0) === '/';
}

// At this point the path should be resolved to a full absolute path, but
// handle relative paths to be safe (might happen when process.cwd() fails)

// Normalize the path
resolvedPath = normalizeArray(filter(resolvedPath.split('/'), function(p) {
    return !!p;
  }), !resolvedAbsolute).join('/');

  return ((resolvedAbsolute ? '/' : '') + resolvedPath) || '.';
};

// path.normalize(path)
// posix version
exports.normalize = function(path) {
var isAbsolute = path.charAt(0) === '/',
    trailingSlash = path.slice(-1) === '/';

// Normalize the path
path = normalizeArray(filter(path.split('/'), function(p) {
    return !!p;
  }), !isAbsolute).join('/');

  if (!path && !isAbsolute) {
    path = '.';
  }
  if (path && trailingSlash) {
    path += '/';
  }
  
  return (isAbsolute ? '/' : '') + path;
};


// posix version
exports.join = function() {
  var paths = Array.prototype.slice.call(arguments, 0);
  return exports.normalize(filter(paths, function(p, index) {
    return p && typeof p === 'string';
  }).join('/'));
};


exports.dirname = function(path) {
  var dir = splitPathRe.exec(path)[1] || '';
  var isWindows = false;
  if (!dir) {
    // No dirname
    return '.';
  } else if (dir.length === 1 ||
      (isWindows && dir.length <= 3 && dir.charAt(1) === ':')) {
    // It is just a slash or a drive letter with a slash
    return dir;
  } else {
    // It is a full dirname, strip trailing slash
    return dir.substring(0, dir.length - 1);
  }
};


exports.basename = function(path, ext) {
  var f = splitPathRe.exec(path)[2] || '';
  // TODO: make this comparison case-insensitive on windows?
  if (ext && f.substr(-1 * ext.length) === ext) {
    f = f.substr(0, f.length - ext.length);
  }
  return f;
};


exports.extname = function(path) {
  return splitPathRe.exec(path)[3] || '';
};

});

require.define("/application.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Application, BottomInstructions, Display, Mode, TopInstructions1, TopInstructions2, TopInstructions3, simpleStartFigure, startFigure;

  Display = require('./display');

  Mode = {
    HOLE: 0,
    CONTOUR: 1,
    VISUALIZE: 2
  };

  TopInstructions1 = "<p>\n  To form a hole, click around inside the outer\n  contour in <b>clockwise</b> order.\n</p>";

  TopInstructions2 = "<p>\n  Click the WebGL canvas at various points in <b>counter-clockwise</b> order to create a simple polygon.\n  It can be concave if you want!\n</p>";

  TopInstructions3 = "<p>\n  The ear clipping algorithm can tessellate concave polygons with holes.\n  To draw your own polygon, click <span class=\"doneButton\">here</span>\n  or press enter.\n</p>";

  BottomInstructions = "<p>\n  Press the <b>d</b> key to delete the most recently added point.  You can also use the mouse to drag\n  existing vertices and edges.  Hold the shift key to drag the entire polyline.\n</p>\n<p>\n  When you're done, click <span class=\"doneButton\">here</span> or press enter.\n</p>";

  startFigure = true;

  simpleStartFigure = false;

  Application = (function() {

    function Application() {
      var c, h, o;
      this.shiftKey = false;
      if (startFigure) {
        if (simpleStartFigure) {
          c = [
            {
              x: 520,
              y: 440
            }, {
              x: 315,
              y: 100
            }, {
              x: 90,
              y: 440
            }
          ];
          h = [
            {
              x: 300,
              y: 290
            }, {
              x: 330,
              y: 290
            }, {
              x: 315,
              y: 380
            }
          ];
        } else {
          c = [
            {
              x: 440,
              y: 502
            }, {
              x: 414,
              y: 438
            }, {
              x: 404,
              y: 355
            }, {
              x: 394,
              y: 298
            }, {
              x: 442,
              y: 278
            }, {
              x: 470,
              y: 265
            }, {
              x: 480,
              y: 252
            }, {
              x: 489,
              y: 232
            }, {
              x: 508,
              y: 198
            }, {
              x: 467,
              y: 173
            }, {
              x: 437,
              y: 236
            }, {
              x: 395,
              y: 251
            }, {
              x: 361,
              y: 257
            }, {
              x: 324,
              y: 212
            }, {
              x: 317,
              y: 170
            }, {
              x: 327,
              y: 150
            }, {
              x: 349,
              y: 125
            }, {
              x: 367,
              y: 82
            }, {
              x: 353,
              y: 56
            }, {
              x: 308,
              y: 22
            }, {
              x: 244,
              y: 40
            }, {
              x: 233,
              y: 75
            }, {
              x: 258,
              y: 146
            }, {
              x: 278,
              y: 159
            }, {
              x: 299,
              y: 216
            }, {
              x: 282,
              y: 277
            }, {
              x: 228,
              y: 246
            }, {
              x: 168,
              y: 180
            }, {
              x: 159,
              y: 167
            }, {
              x: 117,
              y: 207
            }, {
              x: 194,
              y: 249
            }, {
              x: 223,
              y: 277
            }, {
              x: 263,
              y: 304
            }, {
              x: 277,
              y: 385
            }, {
              x: 259,
              y: 406
            }, {
              x: 225,
              y: 429
            }, {
              x: 217,
              y: 435
            }, {
              x: 159,
              y: 496
            }, {
              x: 293,
              y: 520
            }, {
              x: 284,
              y: 451
            }, {
              x: 315,
              y: 406
            }, {
              x: 323,
              y: 381
            }, {
              x: 351,
              y: 391
            }, {
              x: 354,
              y: 421
            }, {
              x: 370,
              y: 458
            }, {
              x: 344,
              y: 487
            }, {
              x: 335,
              y: 535
            }
          ];
          h = [
            {
              x: 348,
              y: 303
            }, {
              x: 340.46979603717466,
              y: 318.6366296493606
            }, {
              x: 323.5495813208737,
              y: 322.49855824363647
            }, {
              x: 309.98062264195164,
              y: 311.6776747823512
            }, {
              x: 309.98062264195164,
              y: 294.3223252176488
            }, {
              x: 323.5495813208737,
              y: 283.50144175636353
            }, {
              x: 340.46979603717466,
              y: 287.3633703506394
            }
          ];
        }
        this.contourPts = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = c.length; _i < _len; _i++) {
            o = c[_i];
            _results.push(new vec2(o.x, o.y));
          }
          return _results;
        })();
        this.holePts = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = h.length; _i < _len; _i++) {
            o = h[_i];
            _results.push(new vec2(o.x, o.y));
          }
          return _results;
        })();
      } else {
        this.contourPts = [];
        this.holePts = [];
      }
      this.mode = Mode.HOLE;
      this.dragList = [];
      if (this.initDisplay()) {
        this.nextMode();
        this.assignEventHandlers();
        this.requestAnimationFrame();
      }
      if (startFigure) {
        this.updateDisplay();
      }
    }

    Application.prototype.initDisplay = function() {
      var c, gl, height, msg, width;
      try {
        c = $('canvas').get(0);
        gl = c.getContext('experimental-webgl', {
          antialias: true
        });
        if (!gl) {
          throw new Error();
        }
      } catch (error) {
        msg = 'Alas, your browser does not support WebGL.';
        $('canvas').replaceWith("<p class='error'>" + msg + "</p>");
      }
      if (!gl) {
        return false;
      }
      width = parseInt($('canvas').css('width'));
      height = parseInt($('canvas').css('height'));
      return this.display = new Display(gl, width, height);
    };

    Application.prototype.requestAnimationFrame = function() {
      var onTick,
        _this = this;
      onTick = function() {
        return _this.tick();
      };
      return window.requestAnimationFrame(onTick, this.canvas);
    };

    Application.prototype.tick = function() {
      this.requestAnimationFrame();
      return this.display.render();
    };

    Application.prototype.updateDisplay = function() {
      var holes, triangles;
      this.display.setPoints(this.contourPts, this.holePts);
      holes = [this.holePts];
      triangles = POLYGON.tessellate(this.contourPts, holes);
      return this.display.setTriangles(triangles);
    };

    Application.prototype.updateHighlight = function(x, y) {
      var e, p;
      if (this.shiftKey) {
        this.display.highlightPoint = -2;
        this.display.setHighlightEdge(-1);
        return;
      }
      p = this.getVertex(x, y);
      e = p === -1 ? this.getEdge(x, y) : -1;
      if (this.mode === Mode.HOLE) {
        if (p !== -1) {
          p = p + this.contourPts.length;
        }
        if (e !== -1) {
          e = e + this.contourPts.length;
        }
      }
      this.display.highlightPoint = p;
      return this.display.setHighlightEdge(e);
    };

    Application.prototype.getVertex = function(x, y) {
      var d, i, p, pt, _i, _len, _ref;
      if (!this.pts) {
        return -1;
      }
      p = new vec2(x, y);
      _ref = this.pts;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        pt = _ref[i];
        d = pt.distanceToSquared(p);
        if (d < 25) {
          return i;
        }
      }
      return -1;
    };

    Application.prototype.getEdge = function(x, y) {
      var d, i, p, pt, v, w, _i, _len, _ref;
      if (!this.pts) {
        return -1;
      }
      p = new vec2(x, y);
      _ref = this.pts;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        pt = _ref[i];
        v = this.pts[i];
        w = this.pts[(i + 1) % this.pts.length];
        d = distToSegmentSquared(p, v, w);
        if (d < 25) {
          return i;
        }
      }
      return -1;
    };

    Application.prototype.onDown = function(x, y) {
      var a, b, dragItem, e, item, mouse, v, _i, _ref;
      mouse = new vec2(x, y);
      if (this.shiftKey) {
        this.dragList = [];
        for (e = _i = 0, _ref = this.pts.length; 0 <= _ref ? _i < _ref : _i > _ref; e = 0 <= _ref ? ++_i : --_i) {
          item = {
            offset: new vec2(),
            index: e
          };
          item.offset.sub(this.pts[item.index], mouse);
          this.dragList.push(item);
        }
        $('canvas').css({
          cursor: 'none'
        });
        return;
      }
      v = this.getVertex(x, y);
      if (v !== -1) {
        dragItem = {
          offset: new vec2(),
          index: v
        };
        dragItem.offset.sub(this.pts[v], mouse);
        this.dragList = [dragItem];
        $('canvas').css({
          cursor: 'none'
        });
        return;
      }
      e = this.getEdge(x, y);
      if (e === -1) {
        return;
      }
      a = {
        offset: new vec2(),
        index: e
      };
      b = {
        offset: new vec2(),
        index: e + 1
      };
      b.index = b.index % this.pts.length;
      a.offset.sub(this.pts[a.index], mouse);
      b.offset.sub(this.pts[b.index], mouse);
      this.dragList = [a, b];
      return $('canvas').css({
        cursor: 'none'
      });
    };

    Application.prototype.onUp = function(x, y) {
      var item, mouse, _i, _len, _ref;
      if (!this.pts) {
        return;
      }
      mouse = new vec2(x, y);
      if (!this.dragList.length) {
        this.pts.push(mouse);
      } else {
        $('canvas').css({
          cursor: 'default'
        });
        _ref = this.dragList;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          this.pts[item.index].add(item.offset, mouse);
        }
        this.dragList = [];
      }
      return this.updateDisplay();
    };

    Application.prototype.onMove = function(x, y) {
      var item, mouse, _i, _len, _ref;
      if (!this.pts) {
        return;
      }
      if (!this.dragList.length) {
        this.updateHighlight(x, y);
        return;
      }
      mouse = new vec2(x, y);
      _ref = this.dragList;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        this.pts[item.index].add(item.offset, mouse);
      }
      return this.updateDisplay();
    };

    Application.prototype.removePoint = function() {
      if (this.pts.length < 1) {
        return;
      }
      this.pts.pop();
      return this.updateDisplay();
    };

    Application.prototype.nextMode = function() {
      if (this.mode === Mode.CONTOUR) {
        this.mode = Mode.HOLE;
        this.pts = this.holePts;
        this.display.freezeContour = true;
        this.display.visualize = false;
        $('#top-instructions').html(TopInstructions1);
        $('#bottom-instructions').html(BottomInstructions);
      } else if (this.mode === Mode.HOLE) {
        this.mode = Mode.VISUALIZE;
        this.pts = null;
        this.display.visualize = true;
        this.display.setHighlightEdge(-1);
        this.display.highlightPoint = -1;
        $('#top-instructions').html(TopInstructions3);
        $('#bottom-instructions').html('');
      } else if (this.mode === Mode.VISUALIZE) {
        if (startFigure) {
          this.contourPts = [];
          this.holePts = [];
          startFigure = false;
        }
        this.mode = Mode.CONTOUR;
        this.pts = this.contourPts;
        this.display.freezeContour = false;
        this.display.visualize = false;
        $('#top-instructions').html(TopInstructions2);
        $('#bottom-instructions').html(BottomInstructions);
      }
      return this.updateDisplay();
    };

    Application.prototype.circlify = function() {
      var dtheta, flip, pt, radius, theta, _i, _len, _ref;
      this.pts.push(new vec2(0, 0));
      dtheta = 2 * Math.PI / this.pts.length;
      theta = 0;
      flip = this.mode === Mode.CONTOUR ? -1 : +1;
      radius = this.mode === Mode.CONTOUR ? 200 : 20;
      _ref = this.pts;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        pt = _ref[_i];
        pt.x = 300 + radius * Math.cos(theta);
        pt.y = 300 + flip * radius * Math.sin(theta);
        theta = theta + dtheta;
      }
      return this.updateDisplay();
    };

    Application.prototype.setShiftKey = function() {
      if (this.shiftKey) {
        this.display.highlightPoint = -2;
        return this.display.setHighlightEdge(-1);
      } else if (this.display.highlightPoint === -2) {
        return this.display.highlightPoint = -1;
      }
    };

    Application.prototype.dumpPoints = function() {
      console.info("contourPts = ", JSON.stringify(this.contourPts));
      return console.info("holePts = ", JSON.stringify(this.holePts));
    };

    Application.prototype.assignEventHandlers = function() {
      var c,
        _this = this;
      $(document).bind('keydown', function(e) {
        if (e.keyCode === 16) {
          _this.shiftKey = true;
          return _this.setShiftKey(_this.shiftKey);
        }
      });
      $(document).bind('keyup', function(e) {
        if (e.keyCode === 16) {
          _this.shiftKey = false;
          return _this.setShiftKey(_this.shiftKey);
        }
      });
      $(document).on('click', '.doneButton', function() {
        return _this.nextMode();
      });
      c = $('canvas');
      c.mousemove(function(e) {
        var x, y;
        x = e.clientX - c.position().left;
        y = e.clientY - c.position().top;
        return _this.onMove(x, y);
      });
      c.mousedown(function(e) {
        var x, y;
        x = e.clientX - c.position().left;
        y = e.clientY - c.position().top;
        _this.onDown(x, y);
        return e.originalEvent.preventDefault();
      });
      c.mouseup(function(e) {
        var x, y;
        x = e.clientX - c.position().left;
        y = e.clientY - c.position().top;
        return _this.onUp(x, y);
      });
      return $(document).keyup(function(e) {
        var s;
        s = String.fromCharCode(e.keyCode);
        if (s === 'D') {
          _this.removePoint();
        }
        if (s === 'C') {
          _this.circlify();
        }
        if (s === 'P') {
          _this.dumpPoints();
        }
        if (e.keyCode === 13) {
          return _this.nextMode();
        }
      });
    };

    return Application;

  })();

  module.exports = Application;

}).call(this);

});

require.define("/display.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Display, compileProgram, compilePrograms, compileShader, gl, glCheck, loadTexture, semantics, shaders, showSliceLine;

  gl = null;

  semantics = {
    POSITION: 0,
    VERTEXID: 0,
    NORMAL: 1,
    TEXCOORD: 2
  };

  shaders = {};

  shaders.dot = {
    vs: ['dotvs'],
    fs: ['dotfs'],
    attribs: {
      Position: semantics.POSITION
    }
  };

  shaders.contour = {
    vs: ['contourvs'],
    fs: ['contourfs'],
    attribs: {
      Position: semantics.POSITION
    }
  };

  showSliceLine = false;

  Display = (function() {

    function Display(context, width, height) {
      var _this = this;
      this.width = width;
      this.height = height;
      this.ready = false;
      gl = context;
      this.programs = compilePrograms(shaders);
      loadTexture('textures/PointSprite.png', function(i) {
        _this.pointSprite = i;
        return _this.ready = true;
      });
      this.coordsArray = [];
      this.coordsBuffer = gl.createBuffer();
      this.indexArray = [];
      this.outlineBuffer = gl.createBuffer();
      this.indexBuffer = gl.createBuffer();
      this.hotEdgeBuffer = gl.createBuffer();
      this.sliceEdgeBuffer = gl.createBuffer();
      this.sliceEdgeBuffer.enabled = false;
      this.highlightPoint = -1;
      this.highlightEdge = -1;
      this.visualize = false;
      gl.clearColor(0.9, 0.9, 0.9, 1.0);
      gl.lineWidth(2);
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    }

    Display.prototype.render = function() {
      var mv, numHolePoints, pointCount, pointOffset, program, proj, stride;
      if (!this.ready) {
        return;
      }
      gl.clear(gl.COLOR_BUFFER_BIT);
      if (this.coordsArray.length === 0) {
        return;
      }
      mv = new mat4();
      proj = new mat4();
      proj.makeOrthographic(0, 600, 0, 600, 0, 1);
      gl.bindBuffer(gl.ARRAY_BUFFER, this.coordsBuffer);
      gl.enableVertexAttribArray(semantics.POSITION);
      gl.vertexAttribPointer(semantics.POSITION, 2, gl.FLOAT, false, stride = 8, 0);
      program = this.programs.contour;
      gl.useProgram(program);
      gl.uniformMatrix4fv(program.modelview, false, mv.elements);
      gl.uniformMatrix4fv(program.projection, false, proj.elements);
      if (this.indexArray.length > 0) {
        program = this.programs.contour;
        gl.useProgram(program);
        gl.uniform4f(program.color, 0.25, 0.25, 0, 0.5);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
        gl.drawElements(gl.TRIANGLES, 3 * this.indexArray.length, gl.UNSIGNED_SHORT, 0);
        if (this.visualize) {
          gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.outlineBuffer);
          gl.drawElements(gl.LINES, 6 * this.indexArray.length, gl.UNSIGNED_SHORT, 0);
        }
      }
      if (this.coordsArray.length > 1) {
        program = this.programs.contour;
        gl.useProgram(program);
        gl.uniform4f(program.color, 0, 0.4, 0.8, 1);
        gl.drawArrays(gl.LINE_LOOP, 0, this.numContourPoints);
        numHolePoints = this.coordsArray.length - this.numContourPoints;
        if (numHolePoints) {
          gl.uniform4f(program.color, 0.8, 0.4, 0, 1);
          gl.drawArrays(gl.LINE_LOOP, this.numContourPoints, numHolePoints);
          if (showSliceLine && this.sliceEdgeBuffer.enabled) {
            gl.uniform4f(program.color, 1, 0, 0, 1);
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.sliceEdgeBuffer);
            gl.drawElements(gl.LINES, 2, gl.UNSIGNED_SHORT, 0);
          }
        }
        if (this.highlightEdge > -1) {
          gl.lineWidth(4);
          gl.uniform4f(program.color, 0, 0, 0, 1);
          gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.hotEdgeBuffer);
          gl.drawElements(gl.LINES, 2, gl.UNSIGNED_SHORT, 0);
          gl.lineWidth(2);
        }
      }
      program = this.programs.dot;
      gl.useProgram(program);
      gl.uniformMatrix4fv(program.modelview, false, mv.elements);
      gl.uniformMatrix4fv(program.projection, false, proj.elements);
      gl.uniform1f(program.pointSize, 8);
      gl.bindTexture(gl.TEXTURE_2D, this.pointSprite);
      if (!this.freezeContour) {
        pointOffset = 0;
        pointCount = this.numContourPoints;
      } else {
        pointOffset = this.numContourPoints;
        pointCount = this.coordsArray.length - this.numContourPoints;
      }
      if (pointCount === 0 || this.visualize) {
        gl.disableVertexAttribArray(semantics.POSITION);
        return;
      }
      gl.uniform4f(program.color, 0.7, 0.2, 0.2, 1);
      gl.drawArrays(gl.POINTS, pointOffset, 1);
      if (pointCount > 1) {
        gl.uniform4f(program.color, 0, 0, 0, 1);
        gl.drawArrays(gl.POINTS, pointOffset + 1, pointCount - 1);
      }
      if (this.highlightPoint !== -1) {
        program = this.programs.dot;
        gl.useProgram(program);
        gl.uniform1f(program.pointSize, 14);
        gl.uniform4f(program.color, 0, 0, 0, 1);
        if (this.highlightPoint > -1) {
          gl.drawArrays(gl.POINTS, this.highlightPoint, 1);
        } else {
          gl.drawArrays(gl.POINTS, pointOffset, pointCount);
        }
      }
      return gl.disableVertexAttribArray(semantics.POSITION);
    };

    Display.prototype.setPoints = function(contourPts, holePts) {
      var typedArray;
      this.numContourPoints = contourPts.length;
      this.coordsArray = contourPts.concat(holePts);
      if (!this.coordsArray.length) {
        return;
      }
      typedArray = new Float32Array(flatten(this.coordsArray));
      gl.bindBuffer(gl.ARRAY_BUFFER, this.coordsBuffer);
      gl.bufferData(gl.ARRAY_BUFFER, typedArray, gl.STATIC_DRAW);
      return glCheck('Error when trying to create points VBO');
    };

    Display.prototype.setSliceEdge = function(endpoints) {
      var typedArray, v0, v1;
      if (!endpoints.length) {
        this.sliceEdgeBuffer.enabled = false;
        return;
      }
      this.sliceEdgeBuffer.enabled = true;
      v0 = endpoints[0];
      v1 = endpoints[1] + this.numContourPoints;
      typedArray = new Uint16Array([v0, v1]);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.sliceEdgeBuffer);
      return gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, typedArray, gl.STATIC_DRAW);
    };

    Display.prototype.setHighlightEdge = function(edge) {
      var next, numHolePoints, typedArray;
      this.highlightEdge = edge;
      if (edge === -1) {
        return;
      }
      if (edge < this.numContourPoints) {
        next = (edge + 1) % this.coordsArray.length;
      } else {
        numHolePoints = this.coordsArray.length - this.numContourPoints;
        next = (edge - this.numContourPoints + 1) % numHolePoints;
        next = next + this.numContourPoints;
      }
      typedArray = new Uint16Array([edge, next]);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.hotEdgeBuffer);
      return gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, typedArray, gl.STATIC_DRAW);
    };

    Display.prototype.setTriangles = function(inds) {
      var outlines, tri, typedArray, _i, _len, _ref;
      this.indexArray = inds.slice(0);
      typedArray = new Uint16Array(flatten(this.indexArray));
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, typedArray, gl.STATIC_DRAW);
      glCheck('Error when trying to create index VBO');
      outlines = [];
      _ref = this.indexArray;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        tri = _ref[_i];
        outlines.push(tri[0]);
        outlines.push(tri[1]);
        outlines.push(tri[1]);
        outlines.push(tri[2]);
        outlines.push(tri[2]);
        outlines.push(tri[0]);
      }
      typedArray = new Uint16Array(outlines);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.outlineBuffer);
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, typedArray, gl.STATIC_DRAW);
      return glCheck('Error when trying to create outlines VBO');
    };

    return Display;

  })();

  glCheck = function(msg) {
    if (gl.getError() !== gl.NO_ERROR) {
      return console.error(msg);
    }
  };

  compilePrograms = function(shaders) {
    var name, programs, shd;
    programs = {};
    for (name in shaders) {
      shd = shaders[name];
      programs[name] = compileProgram(shd.vs, shd.fs, shd.attribs);
    }
    return programs;
  };

  compileProgram = function(vNames, fNames, attribs) {
    var fShader, key, numUniforms, program, status, u, uniforms, vShader, value, _i, _len;
    vShader = compileShader(vNames, gl.VERTEX_SHADER);
    fShader = compileShader(fNames, gl.FRAGMENT_SHADER);
    program = gl.createProgram();
    gl.attachShader(program, vShader);
    gl.attachShader(program, fShader);
    for (key in attribs) {
      value = attribs[key];
      gl.bindAttribLocation(program, value, key);
    }
    gl.linkProgram(program);
    status = gl.getProgramParameter(program, gl.LINK_STATUS);
    if (!status) {
      console.error("Could not link " + vNames + " with " + fNames);
    }
    numUniforms = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS);
    uniforms = (function() {
      var _i, _results;
      _results = [];
      for (u = _i = 0; 0 <= numUniforms ? _i < numUniforms : _i > numUniforms; u = 0 <= numUniforms ? ++_i : --_i) {
        _results.push(gl.getActiveUniform(program, u).name);
      }
      return _results;
    })();
    for (_i = 0, _len = uniforms.length; _i < _len; _i++) {
      u = uniforms[_i];
      program[u] = gl.getUniformLocation(program, u);
    }
    return program;
  };

  compileShader = function(names, type) {
    var handle, id, source, status;
    source = ((function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = names.length; _i < _len; _i++) {
        id = names[_i];
        _results.push($('#' + id).text());
      }
      return _results;
    })()).join();
    handle = gl.createShader(type);
    gl.shaderSource(handle, source);
    gl.compileShader(handle);
    status = gl.getShaderParameter(handle, gl.COMPILE_STATUS);
    if (!status) {
      console.error(gl.getShaderInfoLog(handle));
    }
    return handle;
  };

  loadTexture = function(filename, onLoaded) {
    var tex;
    tex = gl.createTexture();
    tex.image = new Image();
    tex.image.onload = function() {
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, tex.image);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.bindTexture(gl.TEXTURE_2D, null);
      glCheck('Error when loading texture');
      return onLoaded(tex);
    };
    return tex.image.src = filename;
  };

  module.exports = Display;

}).call(this);

});

require.define("/demo.coffee", function (require, module, exports, __dirname, __filename) {
    (function() {
  var Application;

  Application = require('./application');

  $(document).ready(function() {
    return window.app = new Application;
  });

}).call(this);

});
require("/demo.coffee");
