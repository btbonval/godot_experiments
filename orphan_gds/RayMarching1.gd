extends Node2D

# Author: Bryan Bonvallet
# Copyright: (c) 2020 Bryan Bonvallet
# License: MIT
# Purpose: Learn Godot 2D
# Motivation: Sebastian Lague's video about Ray Marching
# Setup: Attach this script to a scene's root node. Add Polygon2Ds (no collision)

var focal_loc = Vector2(300, 150)
var focal_traj = Vector2(0,0)
var focal_r = 0
var focal_theta = 0
const draw_speed = 1
const move_speed = 50
const delta_thresh = 2
var delta_accum = delta_thresh
const length_epsilon = 0.01

var MAX_VECTOR = Vector2(1e6,1e6)
var MIN_VECTOR = Vector2(-1,-1)

var memoize_circles = []
var memoize_boundaries = {}
var segment_chain = []
var segment_r = []

# Called when objects are first built.
func _ready():
	findChildBoundaries()
	findWindowBoundaries()

# Called when the node enters the scene tree for the first time.
func _draw():
	# Highlight the polygon boundaries that were previously calculated.
	for bound in memoize_circles:
		draw_circle(Vector2(bound.position.x, bound.position.y), bound.size.x, Color(0,1,0))
	# Draw background radii for line segments.
	for i in range(0, len(segment_chain)):
		draw_circle(segment_chain[i], segment_r[i], Color(0.2,0.2,0.2))
	# Draw line segments and terminal points
	for i in range(0, len(segment_chain)):
		draw_circle(segment_chain[i], 2, Color(0.5,1,1))
		# 0th segment is a single point which must be drawn,
		# but cannot be used by itself to draw a line.
		if i > 0:
			draw_line(segment_chain[i-1], segment_chain[i], Color(0.5,1,1))
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Spin the scan line continously over 2pi radians
	focal_theta = fmod(focal_theta + draw_speed*delta, 6.28)

	# Every so often, update the epicenter trajectory
	delta_accum = delta_accum + delta
	if delta_accum > delta_thresh:
		focal_traj = move_speed * delta * Vector2(randf() - 0.5, randf() - 0.5)
		delta_accum = 0

	# Update the epicenter based on current trajectory
	focal_loc = focal_loc + focal_traj

	# Build the segment chain sweeping out of the epicenter.
	segment_chain = []
	segment_r = []
	focal_r = nextLine(focal_loc)
	var last_r = focal_r
	var last_p = focal_loc
	while last_r != null:
		last_p = projectLine(last_p, last_r)
		last_r = nextLine(last_p)

	# Redraw
	update()

###

# From point p, project out r units out along the current sweep angle.
# Return a new point.
func projectLine(p: Vector2, r: float) -> Vector2:
	return p + Vector2(r * cos(focal_theta), r * sin(focal_theta))

# From a given point p, derive the next line segment that should follow.
# Returns the segment length or null if collision.
func nextLine(p: Vector2):
	var d = shortestDistance(p)
	if d < length_epsilon:
		# The segment is too small to continue adding segments.
		return null
	# Track segment and segment length for drawing purposes
	segment_chain.append(p)
	segment_r.append(d)
	return d

# From given point p, find the nearest object or scene boundary.
# Returns the distance from the point to the nearest thing.
func shortestDistance(p: Vector2) -> float:
	var r = signedDstToScreen(p)
	for bound in memoize_circles:
		var test = min(signedDstToCircle(p, bound.position, bound.size.x), r)
		if (test < r):
			r = test
	return r

# Sets vectors to capture the screen's upper left and lower right bounds.
func findWindowBoundaries():
	var c = get_viewport_rect()
	MIN_VECTOR = Vector2(c.position.x, c.position.y)
	MAX_VECTOR = MIN_VECTOR + Vector2(c.size.x, c.size.y)

# Iterate through each child of this node, treating it as a Polygon2D.
# Calculate the circle bound that encapsulates each polygon,
# memoize them for later.
func findChildBoundaries():
	var cs = get_children()
	memoize_circles = []
	memoize_boundaries = {}
	for c in cs:
		var cp = (c as Polygon2D)
		var bound = BoundCirc(PolyBound(cp))
		# bound.position is relative to its parent polygon container.
		# Use cp.position to find position relative to this scene.
		bound.position = bound.position + cp.position
		memoize_circles.append(bound)
		# This assumes each bound will be unique to quickly retrieve the
		# correct polygon node given its bounds.
		# If no polygons overlap, this assumption should be satisfied.
		memoize_boundaries[bound] = c

# Given a rectangular bounding box, find a circular bounding box that
# encapsulates it.
# Returns a Rect2 with position of circle center and size.x of radius.
# There might be a more appropriate data structure for this.
func BoundCirc(box:Rect2) -> Rect2:
	var center_x = box.position.x + box.size.x/2
	var center_y = box.position.y + box.size.y/2
	var radius = max(box.size.x, box.size.y)/1.7
	return Rect2(center_x, center_y, radius, 0)

# Find the minimum x and y of two points.
# Returns a point containing xmin and ymin.
func minv(a:Vector2, b:Vector2) -> Vector2:
	return Vector2(min(a.x,b.x),min(a.y,b.y))

# Find the maximum x and y of two points.
# Returns a point containing xmax and ymax.
func maxv(a:Vector2, b:Vector2) -> Vector2:
	return Vector2(max(a.x,b.x),max(a.y,b.y))

# Iterate through each point of a polygon p to find a rectangular
# convex hull with encapsulates it.
# Returns a Rect2 with the rectangular convex hull.
func PolyBound(p: Polygon2D) -> Rect2:
	var min_vec = MAX_VECTOR
	var max_vec = MIN_VECTOR
	for v in p.polygon:
		min_vec = minv(v,min_vec)
		max_vec = maxv(v,max_vec)
	return Rect2(min_vec.x, min_vec.y, max_vec.x-min_vec.x, max_vec.y-min_vec.y)

###

# Find the length from the origin to the given point v.
# Returns length as a float.
func length(v: Vector2) -> float:
	return sqrt(v.x*v.x+v.y*v.y)

# Find distance from given point p to the center of some circle and its radius.
# Returns the distance as a float.
func signedDstToCircle(p: Vector2, center: Vector2, radius: float) -> float:
	return length(center-p) - radius;

# Find the minimum distance from given point p to the nearest edge of the
# viewport.
# Returns the distance as a float.
func signedDstToScreen(p: Vector2) -> float:
	var d = minv(p-MIN_VECTOR,MAX_VECTOR-p)
	return min(d.x, d.y)
