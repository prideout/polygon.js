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

# MAIN EAR CLIPPING ALGORITHM
#
# This is an n-squared algorithm; much better algorithms exist.
#
# TODO remove all calls to indexOf by creating maps
#
# coords  ... coordinate list representing the original polygon.
# polygon ... index list into original polygon; represents the clipped polygon.
# reflex  ... index list into original polygon for angles > 180 degrees.
# ncurr, nprev, nnext ... current/previous/next indices into 'coords'
# pcurr, pprev, pnext ... current/previous/next indices into 'polygon'
#
triangulate = (coords) ->

  # First handle the degenerate and trivial cases.
  return [] if coords.length < 3
  if coords.length is 3
    return [0, 1, 2]

  # Define a function that checks if a vert is an ear.  Ears are convex verts that form
  # triangles with their neighbors such that the triangle does not contain any other verts.
  # This is a n-squared operation.
  reflex = []
  polygon = [0...(coords.length)]
  checkEar = (ncurr) ->
    pcurr = polygon.indexOf ncurr
    pprev = (pcurr + polygon.length - 1) % polygon.length
    pnext = (pcurr + 1) % polygon.length
    nprev = polygon[pprev]
    nnext = polygon[pnext]
    triangle = [nprev, ncurr, nnext]
    tricoords = (coords[i] for i in triangle)
    isEar = true
    for oindex in reflex
      continue if oindex in triangle
      ocoord = coords[oindex]
      if pointInTri ocoord, tricoords
        isEar = false
        break
    isEar

  # Returns true if the angle at the given index is > 180
  isReflexIndex = (ncurr) ->
    pcurr = polygon.indexOf ncurr
    pprev = (pcurr + polygon.length - 1) % polygon.length
    pnext = (pcurr + 1) % polygon.length
    nprev = polygon[pprev]
    nnext = polygon[pnext]
    a = coords[nprev]
    b = coords[ncurr]
    c = coords[nnext]
    return isReflexAngle a, b, c

  # Next, find all reflex verts.
  # We create two variable sized lists to allow quick travel between reflex verts.
  # We also create a fixed-sized "reflexMap" to quickly determine the position of
  # a given vert in the reflex list (an index of -1 indicates concavity).
  concave = []
  reflexMap = []
  for b, ncurr in coords
    if isReflexIndex ncurr
      reflexMap.push reflex.length
      reflex.push ncurr
    else
      reflexMap.push -1
      concave.push ncurr

  # Now find all the initial ears, which are verts that form triangles that
  # don't contain any other verts.  This is a n-squared operation.
  ears = []
  for ncurr in concave
    if checkEar ncurr
      ears.push ncurr

  console.info "prideout"
  console.info "prideout ears    #{ears}"
  console.info "prideout reflex  #{reflex}"
  console.info "prideout concave #{concave}"

  # Remove ears, one by one.  Removing an ear changes the configuration as follows:
  #  - If the neighbor is convex, it remains convex.
  #  - If the neighbor is an ear, it might not stay an ear.
  #  - If the neighbor is reflex, it might become convex and possibly and ear.

  resultingTris = []
  resultingTris

module.exports = triangulate