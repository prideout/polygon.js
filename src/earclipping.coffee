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

# Takes three coordinates, returns true if the angle at
# the second coordinate is > 180
isReflexCoord = (a, b, c) ->
  ac.sub c, a
  ab.sub b, a
  0 > ac.cross ab

# Takes an index and a point list, returns true if the angle
# at the given index is > 180
isReflexIndex = (ncurr, coords) ->
  nprev = (ncurr + coords.length - 1) % coords.length
  nnext = (ncurr + 1) % coords.length
  a = coords[nprev]
  b = coords[ncurr]
  c = coords[nnext]
  return isReflexCoord a, b, c

# MAIN EAR CLIPPING ALGORITHM
#
# This is an n-squared algorithm but at least
# it's nice and simple.
#
triangulate = (coords) ->

  # First handle the trivial cases.
  return [] if coords.length < 3
  if coords.length is 3
    return [0, 1, 2]

  # Next, find all reflex verts.
  reflex = []
  concave = []
  for b, ncurr in coords
    if isReflexIndex ncurr
      reflex.push ncurr
    else
      concave.push ncurr

  # Now find all the initial ears.
  ears = []
  for ncurr in concave
    nprev = (ncurr + coords.length - 1) % coords.length
    nnext = (ncurr + 1) % coords.length
    triangle = [nprev, ncurr, nnext]
    tricoords = (coords[i] for i in triangle)
    isEar = true
    for oindex in reflex
      continue if oindex in triangle
      ocoord = coords[oindex]
      if pointInTri ocoord, tricoords
        isEar = false
        break
    if isEar
      ears.push ncurr

  # Remove ears one by one.
  # If the neighbor is convex, it remains convex.
  # If the neighbor is an ear, it might not stay an ear.
  # If the neighbor is reflex, it might become convex and possibly and ear.

  console.info "prideout"
  console.info "prideout ears    #{ears}"
  console.info "prideout reflex  #{reflex}"
  console.info "prideout concave #{concave}"

  triangles = []
  indices = [0...(coords.length)]

  while triangles.length < coords.length - 2
    if ears.length is 0
      console.info 'the universe has imploded'
      return triangles
    ncurr = ears.pop()
    nprev = (ncurr + coords.length - 1) % coords.length
    nnext = (ncurr + 1) % coords.length
    triangles.push [nprev, ncurr, nnext]

    for adj in [nprev, nnext]
      testEar = false
      if (adj in reflex) and (not isReflexIndex adj, coords)
        reflex.splice (reflex.indexOf adj), 1
        testEar = true
      if testEar or not (adj in reflex)
        nprev = (ncurr + coords.length - 1) % coords.length
        nnext = (ncurr + 1) % coords.length
        triangle = [nprev, ncurr, nnext]
        tricoords = (coords[i] for i in triangle)
        isEar = true
        for oindex in reflex
          continue if oindex in triangle
          ocoord = coords[oindex]
          if pointInTri ocoord, tricoords
            isEar = false
            break
        if isEar
          ears.push ncurr



  triangles

module.exports = triangulate