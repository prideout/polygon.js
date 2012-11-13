# TRIANGULATION OF SIMPLE POLYGONS VIA EAR CLIPPING
#
# This is the n-squared algorithm described by David Eberly.  While faster
# algorithms exist for polygon triangulation, this one is easy to follow.
#
# INPUTS:
#
# coords  ... coordinate list representing the original polygon in CCW order.
# holes   ... list of coordinates lists representing holes in CW order.
#
# Presently the holes list must have 0 or 1 items.  All input coordinates must
# have 'x' and 'y' fields.
#
# OUTPUTS:
#
# triangles ... list of integer indices forming the triangles
#
# INTERNAL VARIABLES:
#
# polygon ... sequence of indices into 'coords'; represents the clipped polygon.
# reflex .... boolean list for reflex angles; one entry per vertex in 'polygon'
# ears ...... indices into 'polygon' for all of its ears
# n, ncurr, nprev, nnext ... indices into 'coords'
# p, pcurr, pprev, pnext ... indices into 'polygon'
#
POLYGON = {}
POLYGON.tessellate = (coords, holes) ->

  vec2 = POLYGON.vec2

  # SCRATCH VECTORS
  ab = new vec2();  bc = new vec2()
  ca = new vec2();  ap = new vec2()
  bp = new vec2();  cp = new vec2()
  ac = new vec2();

  # POINT IN TRIANGLE
  #
  # Walk around the edges and determine if
  # p is to the left or right of each edge.
  # If the answer is the same for all 3 edges,
  # then the point is inside.
  #
  pointInTri = (p, tri) ->
    ab.sub tri[1], tri[0]
    bc.sub tri[2], tri[1]
    ca.sub tri[0], tri[2]
    ap.sub p, tri[0]
    bp.sub p, tri[1]
    cp.sub p, tri[2]
    a = ab.cross ap
    b = bc.cross bp
    c = ca.cross cp
    return true if a < 0 and b < 0 and c < 0
    return true if a > 0 and b > 0 and c > 0
    false

  # IS REFLEX ANGLE
  #
  # Takes three coordinates that form a caret shape.
  # Returns true if the caret angle > 180.
  #
  isReflexAngle = (a, b, c) ->
    ac.sub c, a
    ab.sub b, a
    0 > ac.cross ab

  # INTERSECT SEGMENT X
  #
  # Find the X coordinate within the given line segment
  # that has the given Y value.
  #
  intersectSegmentX = (p0, p1, y) ->
    return p0.x if p0.y == p1.y
    if p0.y < p1.y
      t = (y - p0.y) / (p1.y - p0.y)
      p0.x + t * (p1.x - p0.x)
    else
      t = (y - p1.y) / (p0.y - p1.y)
      p1.x + t * (p0.x - p1.x)

  # Return early for degenerate and trivial cases.
  return [] if coords.length < 3
  if coords.length is 3 and holes.length is 0
    return [0, 1, 2]

  # Define some private variables in this closure.
  reflex = []
  polygon = [0...coords.length]
  reflexCount = 0

  # Finds two mutually visible vertices between the
  # outer contour and the given hole.
  getSlice = (hole) ->
    Mn = 0
    xrightmost = -10000
    for coord, n in hole
      if coord.x > xrightmost
        xrightmost = coord.x
        Mn = n
    M = hole[Mn]
    E = 0.0001
    I = new vec2 10000, M.y
    P = new vec2()
    Pn = -1
    for c0, ncurr in coords
      nnext = (ncurr + 1) % coords.length
      c1 = coords[nnext]
      continue if c0.x < M.x and c1.x < M.x
      continue if c0.x > I.x and c1.x > I.x
      if (c0.y <= M.y <= c1.y) or (c1.y <= M.y <= c0.y)
        x = intersectSegmentX c0, c1, M.y
        if x < I.x
          I.x = x
          if c0.x > c1.x
            P = c0
            Pn = ncurr
          else
            P = c1
            Pn = nnext
    tricoords = [M, I, P]
    Rslope = 1000
    Rn = -1
    for n, p in polygon
      continue if not reflex[p]
      R = coords[n]
      if pointInTri R, tricoords
        dy = Math.abs(R.y - P.y)
        dx = Math.abs(R.x - P.x)
        continue if dx is 0
        slope = dy / dx
        if slope < Rslope
          Rslope = slope
          Rn = n
    Pn = Rn if Rn isnt -1
    slice = [Pn, Mn]

  # Returns the indices of the two adjacent vertices.
  # This honors the topology of the clipped polygon.
  getNeighbors = (pcurr) ->
    pprev = (pcurr + polygon.length - 1) % polygon.length
    pnext = (pcurr + 1) % polygon.length
    [pprev, pnext]

  # Checks if a vert is an ear.  Ears are convex verts that form
  # triangles with their neighbors such that the triangle does not contain any other verts.
  checkEar = (pcurr) ->
    return true if reflexCount is 0
    [pprev, pnext] = getNeighbors pcurr
    ptriangle = [pprev, pcurr, pnext]
    ntriangle = (polygon[p] for p in ptriangle)
    tricoords = (coords[i] for i in ntriangle)
    isEar = true
    for n, p in polygon
      continue if n in ntriangle
      continue if not reflex[p]
      if pointInTri coords[n], tricoords
        isEar = false
        break
    isEar

  # Returns true if the angle at the given index is > 180
  isReflexIndex = (pcurr) ->
    [pprev, pnext] = getNeighbors pcurr
    a = coords[polygon[pprev]]
    b = coords[polygon[pcurr]]
    c = coords[polygon[pnext]]
    return isReflexAngle a, b, c

  # Repair the polygon if it has holes by duplicating verts along
  # a new edge called "slice".  The slice verts must be
  # visible to each other.  (ie, no edge intersections)
  slice = []
  if holes.length and holes[0].length >= 3
    for n, p in polygon
      reflex.push isReflexIndex p
    hole = holes[0]

    # Find any two mutually visible vertices, the first
    # from the outer contour, the second from the hole.
    slice = getSlice hole

    # Clone the outer contour and append the hole verts.
    coords = coords.slice 0
    holeStart = coords.length
    (coords.push h) for h in hole

    # Perform a rotational shift of the indices in 'polygon'
    # such that the slice vertex winds up at the end of the list.
    newPolygon = []
    i = (slice[0] + 1) % polygon.length
    for _ in [0...polygon.length]
      newPolygon.push polygon[i]
      i = (i + 1) % polygon.length

    # Similarly shift the indices of 'hole' and append
    # them to the new polygon.
    i = slice[1]
    for _ in [0...hole.length]
      newPolygon.push holeStart + i
      i = (i + 1) % hole.length

    # Insert the two duplicated verts that occur along
    # the new "slice" edge.
    newPolygon.push newPolygon[polygon.length]
    newPolygon.push newPolygon[polygon.length - 1]
    polygon = newPolygon

  # We're now ready for the ear clipping algorithm.  First,
  # find all reflex verts.
  convex = []
  reflex = []
  reflexCount = 0
  for n, p in polygon
    if isReflexIndex p
      reflex.push true
      reflexCount = reflexCount + 1
    else
      reflex.push false
      convex.push p

  # Next find all the initial ears, which are verts that form triangles that
  # don't contain any other verts.  This is a n-squared operation.
  ears = []
  for p in convex
    if checkEar p
      ears.push p

  # Diagnostic output.
  verbose = false
  if verbose
    console.info ""
    console.info "ears    #{ears}"
    console.info "reflex  #{reflex}"
    console.info "convex  #{convex}"

  # Remove ears, one by one.
  triangles = []
  while polygon.length > 0

    # Remove the index from the ear list.
    pcurr = ears.pop()
    watchdog = watchdog - 1

    # Insert the ear into the triangle list that we're building.
    [pprev, pnext] = getNeighbors pcurr
    ptriangle = [pprev, pcurr, pnext]
    ntriangle = (polygon[p] for p in ptriangle)
    triangles.push ntriangle

    # Remove the ear vertex from the clipped polygon.
    polygon.splice pcurr, 1
    reflex.splice pcurr, 1
    for p, i in ears
      (ears[i] = ears[i] - 1) if p > pcurr
    (pnext = pnext - 1) if pnext > pcurr
    (pprev = pprev - 1) if pprev > pcurr

    # Removing an ear changes the configuration as follows:
    #  - If the neighbor is reflex, it might become convex and possibly an ear.
    #  - If the neighbor is convex, it remains convex and might become an ear.
    #  - If the neighbor is an ear, it might not stay an ear.
    for neighbor in [pprev, pnext]
      if reflex[neighbor] and (not isReflexIndex neighbor)
        reflex[neighbor] = false
        reflexCount = reflexCount - 1
      if not reflex[neighbor]
        isEar = checkEar neighbor
        earIndex = ears.indexOf neighbor
        wasEar = earIndex isnt -1
        if isEar and not wasEar
          ears.push neighbor
        else if not isEar and wasEar
          ears.splice earIndex, 1

  triangles

# SIMPLE 2D VECTOR CLASS
`
POLYGON.vec2 = function ( x, y ) {
	this.x = x || 0;
	this.y = y || 0;
};
POLYGON.vec2.prototype = {
	constructor: POLYGON.vec2,
	set: function ( x, y ) {
		this.x = x;
		this.y = y;
		return this;
	},
	copy: function ( v ) {
		this.x = v.x;
		this.y = v.y;
		return this;
	},
	add: function ( a, b ) {
		this.x = a.x + b.x;
		this.y = a.y + b.y;
		return this;
	},
	sub: function ( a, b ) {
		this.x = a.x - b.x;
		this.y = a.y - b.y;
		return this;
	},
	multiplyScalar: function ( s ) {
		this.x *= s;
		this.y *= s;
		return this;
	},
	divideScalar: function ( s ) {
		if ( s ) {
			this.x /= s;
			this.y /= s;
		} else {
			this.set( 0, 0 );
		}
		return this;
	},
	negate: function() {
		return this.multiplyScalar( - 1 );
	},
	dot: function ( v ) {
		return this.x * v.x + this.y * v.y;
	},
	cross: function ( v ) {
		return this.x * v.y - this.y * v.x;
	},
	lengthSq: function () {
		return this.x * this.x + this.y * this.y;
	},
	length: function () {
		return Math.sqrt( this.lengthSq() );
	},
	normalize: function () {
		return this.divideScalar( this.length() );
	},
	distanceTo: function ( v ) {
		return Math.sqrt( this.distanceToSquared( v ) );
	},
	distanceToSquared: function ( v ) {
		var dx = this.x - v.x, dy = this.y - v.y;
		return dx * dx + dy * dy;
	},
	setLength: function ( l ) {
		return this.normalize().multiplyScalar( l );
	},
	lerpSelf: function ( v, alpha ) {
		this.x += ( v.x - this.x ) * alpha;
		this.y += ( v.y - this.y ) * alpha;
		return this;
	},
	equals: function( v ) {
		return ( ( v.x === this.x ) && ( v.y === this.y ) );
	},
	isZero: function ( v ) {
		return this.lengthSq() < ( v !== undefined ? v : 0.0001 );
	},
	clone: function () {
		return new POLYGON.vec2( this.x, this.y );
	}
};
`
