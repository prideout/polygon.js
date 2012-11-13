The coffeescript source for the ear clipping implementation is [polygon.coffee](http://github.com/prideout/polygon.js/blob/master/src/polygon.coffee).

You can use this code in your Javascript project simply by including [polygon.js](http://github.com/prideout/polygon.js/blob/master/js/polygon.js).

Usage example:

    contour = [{x:0, y:0}, {x:0, y:0}, {x:0, y:0}];
    hole = [[{x:0, y:0}, {x:0, y:0}, {x:0, y:0}]];
    triangles = POLYGON.tessellate(contour, [hole]);
    console.info(triangles)

Generates output like this:

    >> foo bar

Firefox Testing

README

gh-pages branch
