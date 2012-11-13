The coffeescript source for the ear clipping implementation is [polygon.coffee](http://github.com/prideout/polygon.js/blob/master/src/polygon.coffee).

You can use this code in your Javascript project simply by including [polygon.js](http://github.com/prideout/polygon.js/blob/master/js/polygon.js).

Usage example:
      
    contour = [{x:520,y:440},{x:315,y:100},{x:90,y:440}];
    hole = [{x:300,y:290},{x:330,y:290},{x:315,y:380}];
    triangles = POLYGON.tessellate(contour, [hole]);
    console.info("indices: " + triangles);

Generates output like this:

    indices: 4,0,1,3,4,1,3,1,2,5,3,2,5,2,0,5,0,4,4,5,4,4,4,4 

Which looks like this:

![tess](http://github.com/prideout/polygon.js/raw/master/doc/tess.png)

TODO
----

Firefox Testing

gh-pages branch & project description
