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
  var Application, Display;

  Display = require('./display');

  Application = (function() {

    function Application() {
      this.pts = [];
      this.initDisplay();
      this.assignEventHandlers();
      this.requestAnimationFrame();
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
      if (gl) {
        width = parseInt($('canvas').css('width'));
        height = parseInt($('canvas').css('height'));
        return this.display = new Display(gl, width, height);
      }
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
      var _ref;
      this.requestAnimationFrame();
      return (_ref = this.display) != null ? _ref.render() : void 0;
    };

    Application.prototype.onResize = function() {};

    Application.prototype.onClick = function(x, y) {
      this.pts.push(new vec2(x, y));
      if (!(this.display != null)) {
        return;
      }
      return this.display.setPoints(this.pts);
    };

    Application.prototype.assignEventHandlers = function() {
      var _this = this;
      $(window).resize(function() {
        return _this.onResize();
      });
      return $('canvas').click(function(e) {
        var p, x, y;
        p = $('canvas').position();
        x = e.offsetX;
        y = e.offsetY;
        return _this.onClick(x, y);
      });
    };

    return Application;

  })();

  module.exports = Application;

}).call(this);

});

require.define("/display.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Display, gl, glCheck, semantics, shaders;

  gl = null;

  semantics = {
    POSITION: 0,
    VERTEXID: 0,
    NORMAL: 1,
    TEXCOORD: 2
  };

  shaders = {};

  shaders.basic = {
    vs: ['basicvs'],
    fs: ['basicfs'],
    attribs: {
      Position: semantics.POSITION
    }
  };

  glCheck = function(msg) {
    if (gl.getError() !== gl.NO_ERROR) {
      return console.error(msg);
    }
  };

  Display = (function() {

    function Display(context, width, height) {
      this.width = width;
      this.height = height;
      gl = context;
      this.compilePrograms(shaders);
      this.loadTextures();
      this.coordsArray = [];
      this.coordsBuffer = gl.createBuffer();
      gl.clearColor(0.9, 0.9, 0.9, 1.0);
      gl.lineWidth(2);
    }

    Display.prototype.render = function() {
      var mv, program, proj, stride;
      gl.clear(gl.COLOR_BUFFER_BIT);
      if (this.coordsArray.length === 0) {
        return;
      }
      program = this.programs.basic;
      gl.useProgram(program);
      gl.uniform4f(program.color, 1, 0, 0, 1);
      mv = new mat4();
      proj = new mat4();
      proj.makeOrthographic(0, 600, 0, 600, 0, 1);
      gl.uniformMatrix4fv(program.modelview, false, mv.elements);
      gl.uniformMatrix4fv(program.projection, false, proj.elements);
      gl.bindBuffer(gl.ARRAY_BUFFER, this.coordsBuffer);
      gl.enableVertexAttribArray(semantics.POSITION);
      gl.vertexAttribPointer(semantics.POSITION, 2, gl.FLOAT, false, stride = 8, 0);
      gl.drawArrays(gl.POINTS, 0, this.coordsArray.length);
      return gl.disableVertexAttribArray(semantics.POSITION);
    };

    Display.prototype.setPoints = function(pts) {
      var typedArray;
      this.coordsArray = pts.slice(0);
      typedArray = new Float32Array(flatten(this.coordsArray));
      gl.bindBuffer(gl.ARRAY_BUFFER, this.coordsBuffer);
      gl.bufferData(gl.ARRAY_BUFFER, typedArray, gl.STATIC_DRAW);
      glCheck("Error when trying to create VBO");
      return console.info("" + pts.length + " points received: ", typedArray);
    };

    Display.prototype.loadTextures = function() {
      var tex;
      tex = gl.createTexture();
      tex.image = new Image();
      tex.image.onload = function() {
        gl.bindTexture(gl.TEXTURE_2D, tex);
        gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, tex.image);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.bindTexture(gl.TEXTURE_2D, null);
        glCheck("Load texture");
        return console.info("prideout texture laoded");
      };
      tex.image.src = 'textures/PointSprite.png';
      return this.pointSprite = tex;
    };

    Display.prototype.compilePrograms = function(shaders) {
      var name, shd, _results;
      this.programs = {};
      _results = [];
      for (name in shaders) {
        shd = shaders[name];
        _results.push(this.programs[name] = this.compileProgram(shd.vs, shd.fs, shd.attribs));
      }
      return _results;
    };

    Display.prototype.compileProgram = function(vNames, fNames, attribs) {
      var fShader, key, numUniforms, program, status, u, uniforms, vShader, value, _i, _len;
      vShader = this.compileShader(vNames, gl.VERTEX_SHADER);
      fShader = this.compileShader(fNames, gl.FRAGMENT_SHADER);
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

    Display.prototype.compileShader = function(names, type) {
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

    return Display;

  })();

  module.exports = Display;

}).call(this);

});

require.define("/main.coffee", function (require, module, exports, __dirname, __filename) {
    (function() {
  var Application;

  Application = require('./application');

  $(document).ready(function() {
    return window.app = new Application;
  });

}).call(this);

});
require("/main.coffee");
