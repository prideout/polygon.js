If you've got a simple concave polygon with holes and you want to tessellate it into triangles, a simple ear clipping algorithm might be the way to go.  Another popular method is constrained Delaunay triangulation (CDT) but that's a bit overkill if your source data is a directed polyline (as oppposed to a point cloud).

And, if you simply want to *see* the triangles but don't care about storing the topology, you could probably use the stencil buffer trick described [here](http://www.glprogramming.com/red/chapter14.html#name13).

Otherwise, feel free to use my ear clipping implementation!  It's written in coffeescript ([polygon.coffee](http://github.com/prideout/polygon.js/blob/master/src/polygon.coffee)) but it's also available as a single-file Javascript library: [polygon.js](http://github.com/prideout/polygon.js/blob/master/js/polygon.js).

Javascript usage example:
      
    contour = [{x:520,y:440},{x:315,y:100},{x:90,y:440}];
    hole = [{x:300,y:290},{x:330,y:290},{x:315,y:380}];
    triangles = POLYGON.tessellate(contour, [hole]);
    console.info("indices: " + triangles);

Generates output like this:

    indices: 4,0,1,3,4,1,3,1,2,5,3,2,5,2,0,5,0,4,4,5,4,4,4,4 

The triangle indices refer to a point list that is the concatenation of `contour` and `hole`.  Visually, the tessellation for this example looks like this:

![tess](http://github.com/prideout/polygon.js/raw/master/doc/tess.png)

Of course, ear clipping can handle much more complex polygons, such as:

![fancy](http://github.com/prideout/polygon.js/raw/master/doc/fancy.png)

To try it out for yourself, go [here](http://github.prideout.net/polygon.js).