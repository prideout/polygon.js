ab = new vec2();  bc = new vec2()
ca = new vec2();  ap = new vec2()
bp = new vec2();  cp = new vec2()
ac = new vec2();

verbose = false

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

# MAIN EAR CLIPPING ALGORITHM
#
# This is an n-squared algorithm; much better algorithms exist.
#
# coords  ... coordinate list representing the original polygon.
# polygon ... index list into original polygon; represents the clipped polygon.
# clipmap ... maps from an "original" index to an index into the clipped polygon.
# reflex  ... boolean list for reflex angles; one entry per original vertex
# ncurr, nprev, nnext ... current/previous/next indices into 'coords'
# pcurr, pprev, pnext ... current/previous/next indices into 'polygon'
#
triangulate = (coords) ->

  # Return early for degenerate and trivial cases.
  return [] if coords.length < 3
  if coords.length is 3
    return [[0, 1, 2]]

  # Define some private variables in this closure.
  reflex = []
  polygon = [0...coords.length]
  clipmap = [0...coords.length]

  # Returns the indices of the two adjacent vertices.
  # This honors the topology of the clipped polygon, although
  # the input & output integers are indices into the original polygon.
  getNeighbors = (ncurr) ->
    pcurr = clipmap[ncurr]
    pprev = (pcurr + polygon.length - 1) % polygon.length
    pnext = (pcurr + 1) % polygon.length
    nprev = polygon[pprev]
    nnext = polygon[pnext]
    [nprev, nnext]

  # Checks if a vert is an ear.  Ears are convex verts that form
  # triangles with their neighbors such that the triangle does not contain any other verts.
  # This is a n-squared operation.
  checkEar = (ncurr) ->
    [nprev, nnext] = getNeighbors ncurr
    triangle = [nprev, ncurr, nnext]
    tricoords = (coords[i] for i in triangle)
    isEar = true
    for oindex in polygon
      continue if oindex in triangle
      continue if not reflex[oindex]
      ocoord = coords[oindex]
      if pointInTri ocoord, tricoords
        isEar = false
        break
    isEar

  # Returns true if the angle at the given index is > 180
  isReflexIndex = (ncurr) ->
    [nprev, nnext] = getNeighbors ncurr
    a = coords[nprev]
    b = coords[ncurr]
    c = coords[nnext]
    return isReflexAngle a, b, c

  # Now for the algorithm.  First, find all reflex verts.
  convex = []
  for b, ncurr in coords
    if isReflexIndex ncurr
      reflex.push true
    else
      reflex.push false
      convex.push ncurr

  # Next find all the initial ears, which are verts that form triangles that
  # don't contain any other verts.  This is a n-squared operation.
  ears = []
  for ncurr in convex
    if checkEar ncurr
      ears.push ncurr

  # Diagnostic output.
  if verbose
    console.info ""
    console.info "ears    #{ears}"
    console.info "reflex  #{reflex}"
    console.info "convex  #{convex}"

  # Remove ears, one by one.
  triangles = []
  while triangles.length < coords.length - 2

    # Remove the index from the ear list.
    ncurr = ears.pop()

    # Insert the ear into the triangle list that we're building.
    [nprev, nnext] = getNeighbors ncurr
    triangles.push [nprev, ncurr, nnext]

    # Remove the ear vertex from the clipped polygon.
    polygon.splice clipmap[ncurr], 1
    for n in [ncurr...clipmap.length]
      clipmap[n] = clipmap[n] - 1

    # Removing an ear changes the configuration as follows:
    #  - If the neighbor is reflex, it might become convex and possibly an ear.
    #  - If the neighbor is convex, it remains convex and might become an ear.
    #  - If the neighbor is an ear, it might not stay an ear.
    for neighbor in [nprev, nnext]
      if reflex[neighbor] and (not isReflexIndex neighbor)
        reflex[neighbor] = false
      if not reflex[neighbor]
        isEar = checkEar neighbor
        earIndex = ears.indexOf neighbor
        wasEar = earIndex isnt -1
        if isEar and not wasEar
          ears.push neighbor
        else if not isEar and wasEar
          ears.splice earIndex, 1

  triangles

module.exports = triangulate