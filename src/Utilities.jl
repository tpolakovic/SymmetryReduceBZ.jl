module Utilities

import LinearAlgebra: cross, dot, norm
import LinearAlgebra.BLAS: gemv
import Distances: euclidean
import Base.Iterators: flatten
import QHull: Chull

@doc """
    affine_trans(pts)

Calculate the affine transformation that maps the points to the xy-plane.

# Arguments
- `pts::AbstractMatrix{<:Real}`: Cartesian points as the columns of a matrix.
    The points must all lie on a plane in 3D.

# Returns
- `M::AbstractMatrix{<:Real}`: the affine transformation matrix that operates
    on points in homogeneous coordinates from the left.

# Examples
```jldoctest
using SymmetryReduceBZ
pts = [0.5 0.5 0.5; 0.5 -0.5 0.5; -0.5 0.5 0.5; -0.5 -0.5 0.5]'
SymmetryReduceBZ.Utilities.affine_trans(pts)
# output
4×4 Matrix{Float64}:
  0.0  -1.0   0.0  0.5
 -1.0   0.0   0.0  0.5
  0.0   0.0  -1.0  0.5
  0.0   0.0   0.0  1.0
```
"""
function affine_trans(pts::AbstractMatrix{<:Real})::AbstractMatrix{<:Real}
    a,b,c = [pts[:,i] for i=1:3]

    # Create a coordinate system with two vectors lying on the plane the points
    # lie on.
    u = b-a
    v = c-a
    u = u/norm(u)
    v = v - dot(u,v)*u/dot(u,u)
    v = v/norm(v)
    w = cross(u,v)

    # Augmented matrix of affine transform
    inv(vcat(hcat([u v w],a),[0 0 0 1]))
end

@doc """
    contains(pt,pts;rtol,atol)

Check if a point is contained in a matrix of points as columns.

# Arguments
- `pt::AbstractVector{<:Real}`: a point whose coordinates are the components of 
    a vector.
- `pts::AbstractMatrix{<:Real}`: coordinates of points as columns of a matrix.
- `rtol::Real=sqrt(eps(float(maximum(pts))))`: a relative tolerance for floating
    point comparisons
- `atol::Real=1e-9`: an absolute tolerance for floating point comparisons.

# Returns
- `Bool`: a boolean that indicates the presence or absence of `pt` in `pts`.

# Examples
```jldoctest
import SymmetryReduceBZ.Utilities: contains
pts = Array([1 2; 2 3; 3 4; 4 5]')
pt = [1,2]
contains(pt,pts)
# output
true
```
"""
function contains(pt::AbstractVector{<:Real},pts::AbstractMatrix{<:Real};
        rtol::Real=sqrt(eps(float(maximum(pts)))),atol::Real=1e-9)::Bool
    any(isapprox(pt,pts[:,i],rtol=rtol,atol=atol) for i=1:size(pts,2))
end

@doc """
    contains(array,arrays;rtol,atol)

Check if an array of arrays contains an array.

# Arguments
- `array::AbstractArray`: an array of reals of arbitrary dimension.
- `arrays::AbstractArray`: a nested array of arrays of arbitrary dimension.
- `rtol::Real=sqrt(eps(float(maximum(pts))))`: a relative tolerance for floating
    point comparisons.
- `atol::Real=1e-9`: an absolute tolerance for floating point comparisons.

# Returns
- `Bool`: a boolean that indicates the presence of absence of `array` in
    `arrays`.

# Examples
```jldoctest
import SymmetryReduceBZ.Utilities: contains
arrays = [[1 2; 2 3], [2 3; 4 5]]
array = [1 2; 2 3]
contains(array, arrays)
# output
true
```
"""
function contains(array::AbstractArray,arrays::AbstractArray;
    rtol::Real=sqrt(eps(float(maximum(Iterators.flatten(array))))),
    atol::Real=1e-9)::Bool
    any(isapprox(array,a,rtol=rtol,atol=atol) for a in arrays)
end

@doc """
    edgelengths(basis,radius;rtol,atol)

Calculate the edge lengths of a parallelepiped circumscribed by a sphere.

# Arguments
- `basis::AbstractMatrix{<:Real}`: a 2x2 or 3x3 matrix whose columns give the
    parallelogram or parallelepiped directions, respectively.
- `radius::Real`: the radius of the sphere.
- `rtol::Real=sqrt(eps(float(radius)))`: a relative tolerace for
    floating point comparisons.
- `atol::Real=1e-9`: an absolute tolerance for floating point
    comparisons.

# Returns
- `[la,lb,lc]::AbstractVector{<:Real}`: a list of parallelepiped lengths.

# Examples
```jldoctest
using SymmetryReduceBZ
basis=Array([1. 0. 0.; 0. 1. 0.; 0. 0. 1.])
radius=3.0
SymmetryReduceBZ.Utilities.edgelengths(basis,radius)
# output
3-element Vector{Float64}:
 3.0
 3.0
 3.0
```
"""
function edgelengths(basis::AbstractMatrix{<:Real}, radius::Real;
        rtol::Real=sqrt(eps(float(radius))), atol::Real=1e-9)::AbstractVector{<:Real}

    if radius < 0
        throw(ArgumentError("The radius has to be a positive number."))
    end

    if size(basis) == (2,2)
        (a,b)=[basis[:,i] for i=1:2]
        ax,ay=a
        bx,by=b
        la=2*abs(radius*sqrt(bx^2+by^2)/(ay*bx-ax*by))
        lb=2*abs(radius*sqrt(ax^2+ay^2)/(ay*bx-ax*by))
        return [la,lb]

    elseif size(basis) == (3,3)
        (a,b,c)=[basis[:,i] for i=1:3]
        ax,ay,az=a
        bx,by,bz=b
        cx,cy,cz=c

        la=abs(radius*sqrt((by*cx-bx*cy)^2+(bz*cx-bx*cz)^2+(bz*cy-by*cz)^2)/
            (az*by*cx-ay*bz*cx-az*bx*cy+ax*bz*cy+ay*bx*cz-ax*by*cz))
        lb=abs((radius*sqrt((ay*cx-ax*cy)^2+(az*cx-ax*cz)^2+(az*cy-ay*cz)^2))/
            (az*by*cx-ay*bz*cx-az*bx*cy+ax*bz*cy+ay*bx*cz-ax*by*cz))
        lc=abs(radius*sqrt((ay*bx-ax*by)^2+(az*bx-ax*bz)^2+(az*by-ay*bz)^2)/
            (az*by*cx-ay*bz*cx-az*bx*cy+ax*bz*cy+ay*bx*cz-ax*by*cz))
        return [la,lb,lc]
    else
        throw(ArgumentError("Basis has to be a 2x2 or 3x3 matrix."))
    end
end

@doc """
    get_uniquefacets(ch)

Calculate the unique facets of a convex hull.

# Arguments
- `ch::Chull{<:Real}`: a convex hull in 3D from `QHull`.

# Returns
- `unique_facets::Vector{Vector{Int64}}`: a nested list of the
    indices of points that lie on each face. For example, the points that lie on
    the first face are `ch.points[unique_facets[1],:]`.

# Examples
```jldoctest
import SymmetryReduceBZ.Utilities: get_uniquefacets
import SymmetryReduceBZ.Symmetry: calc_bz
real_latvecs = [1 0 0; 0 1 0; 0 0 1]
atom_types = [0]
atom_pos = Array([0 0 0]')
coordinates = "Cartesian"
bzformat = "convex hull"
makeprim = false
convention = "ordinary"
bz = calc_bz(real_latvecs,atom_types,atom_pos,coordinates,bzformat,makeprim,convention)
get_uniquefacets(bz)
# output
6-element Vector{Vector{Int64}}:
 [1, 2, 3, 4]
 [7, 2, 3, 5]
 [6, 4, 3, 5]
 [7, 2, 1, 8]
 [6, 4, 1, 8]
 [8, 7, 5, 6]
```
"""
function get_uniquefacets(ch::Chull{<:Real})::Vector{Vector{<:Int}}
    facets = ch.facets
    unique_facets = []
    removed=zeros(Int64,size(facets,1))
    for i=1:size(facets,1)
        if removed[i] == 0
            removed[i]=1
            face=ch.simplices[i]
            for j=i+1:size(facets,1)
                if isapprox(facets[i,:],facets[j,:],rtol=1e-6)
                    removed[j]=1
                    append!(face,ch.simplices[j])
                end
            end
            face = unique(reduce(hcat,face)[:])
            # Order the corners of the face either clockwise or
            # counterclockwise.
            face = face[sortpts_perm(Array(ch.points[face,:]'))]
            append!(unique_facets,[face])
        end
    end
    # unique_facets = convert(Array{Array{Int,1}},unique_facets)
    unique_facets
end

@doc """
    function mapto_xyplane(pts)

Map Cartesian points embedded in 3D on a plane to the xy-plane embedded in 2D.

# Arguments
- `pts::AbstractMatrix{<:Real}`: Cartesian points embedded in 3D as columns of a
    matrix.

# Returns
- `AbstractMatrix{<:Real}`: Cartesian points in 2D as columns of a matrix.

# Examples
```jldoctest
using SymmetryReduceBZ
pts = [0.5 -0.5 0.5; 0.5 -0.5 -0.5; 0.5 0.5 -0.5; 0.5 0.5 0.5]'
SymmetryReduceBZ.Utilities.mapto_xyplane(pts)
# output
2×4 Matrix{Float64}:
 0.0  1.0  1.0  0.0
 0.0  0.0  1.0  1.0
```
"""
function mapto_xyplane(pts::AbstractMatrix{<:Real})::AbstractMatrix{<:Real}

    M = affine_trans(pts)
    reduce(hcat,[(M*[pts[:,i]..., 1])[1:2] for i=1:size(pts,2)])
end

@doc """
    sample_circle(basis,radius,offset;rtol,atol)

Sample uniformly within a circle centered about a point.

## Arguments
- `basis::AbstractMatrix{<:Real}`: a 2x2 matrix whose columns are the grid 
    generating vectors.
- `radius::Real`: the radius of the circle.
- `offset::AbstractVector{<:Real}=[0.,0.]`: the xy-coordinates of the center of
    the circle.
- `rtol::Real=sqrt(eps(float(radius)))`: a relative tolerace for floating point
    comparisons.
- `atol::Real=1e-9`: an absolute tolerance for floating point comparisons.

## Returns
- `pts::AbstractMatrix{<:Real}` a matrix whose columns are sample points in Cartesian
    coordinates.

## Examples
```jldoctest
using SymmetryReduceBZ
basis=Array([1. 0.; 0. 1.]')
radius=1.0
offset=[0.,0.]
SymmetryReduceBZ.Utilities.sample_circle(basis,radius,offset)
# output
2×5 Matrix{Float64}:
  0.0  -1.0  0.0  1.0  0.0
 -1.0   0.0  0.0  0.0  1.0
```
"""
function sample_circle(basis::AbstractMatrix{<:Real}, radius::Real,
    offset::AbstractVector{<:Real}=[0.,0.];
    rtol::Real=sqrt(eps(float(radius))), atol::Real=1e-9)::AbstractMatrix{<:Real}

    # Put the offset in lattice coordinates and round.
    (o1,o2)=round.(inv(basis)*offset)
    lens=edgelengths(basis,radius)
    n1,n2=round.(lens) .+ 1

    l=0;
    pt=Array{Float64,1}(undef,2)
    pts=Array{Float64,2}(undef,2,Int((2*n1+1)*(2*n2+1)));
    distances=Array{Float64,1}(undef,size(pts,2))
    for (i,j) in Iterators.product((-n1+o1):(n1+o1),(-n2+o2):(n2+o2))
        l+=1
        pt=gemv('N',float(basis),[i,j])
        pts[:,l]=pt
        distances[l]=euclidean(pt,offset)
    end

    return pts[:,distances.<=radius]

end

@doc """
    sample_sphere(basis,radius,offset;rtol,atol)

Sample uniformly within a sphere centered about a point.

# Arguments
- `basis::AbstractMatrix{<:Real}`: a 3x3 matrix whose columns are the grid generating
    vectors.
- `radius::Real`: the radius of the sphere.
- `offset::AbstractVector{<:Real}=[0.,0.]`: the xy-coordinates of the center of the
    circle.
- `rtol::Real=sqrt(eps(float(radius)))`: a relative tolerace for
    floating point comparisons.
- `atol::Real=1e-9`: an absolute tolerance for floating point
    comparisons.

# Returns
- `pts::AbstractMatrix{<:Real}` a matrix whose columns are sample points in Cartesian
    coordinates.

# Examples
```jldoctest
using SymmetryReduceBZ
basis=Array([1. 0. 0.; 0. 1. 0.; 0. 0. 1.])
radius=1.0
offset=[0.,0.,0.]
SymmetryReduceBZ.Utilities.sample_sphere(basis,radius,offset)
# output
3×7 Matrix{Float64}:
  0.0   0.0  -1.0  0.0  1.0  0.0  0.0
  0.0  -1.0   0.0  0.0  0.0  1.0  0.0
 -1.0   0.0   0.0  0.0  0.0  0.0  1.0
```
"""
function sample_sphere(basis::AbstractMatrix{<:Real}, radius::Real,
    offset::AbstractVector{<:Real}=[0.,0.,0.]; rtol::Real=sqrt(eps(float(radius))),
    atol::Real=1e-9)::AbstractMatrix{<:Real}

    # Put the offset in lattice coordinates and round.
    (o1,o2,o3)=round.(inv(basis)*offset)
    lens=edgelengths(basis,radius)
    n1,n2,n3=round.(lens) .+ 1

    l=0;
    pt=Array{Float64,1}(undef,3)
    pts=Array{Float64,2}(undef,3,Int((2*n1+1)*(2*n2+1)*(2*n3+1)));
    distances=Array{Float64,1}(undef,size(pts,2))
    for (i,j,k) in Iterators.product((-n1+o1):(n1+o1),(-n2+o2):(n2+o2),
                                     (-n3+o3):(n3+o3))
        l+=1
        pt=gemv('N',float(basis),[i,j,k])
        pts[:,l]=pt
        distances[l]=euclidean(pt,offset)
    end

    pts[:,findall(x->(x<radius||isapprox(x,radius,rtol=rtol)),distances)]
end

@doc """
    shoelace(vertices)

Calculate the area of a polygon with the shoelace algorithm.

# Arguments
- `vertices::AbstractMatrix{<:Real}`: the xy-coordinates of the vertices
    of the polygon as the columns of a matrix.

# Returns
- `<:Real`: the area of the polygon.

# Examples
```jldoctest
import SymmetryReduceBZ.Utilities: shoelace
pts = [0 0 1; -1 1 0]
shoelace(pts)
# output
1.0
````
"""
function shoelace(vertices)
    xs = vertices[1,:]
    ys = vertices[2,:]
    abs(xs[end]*ys[1] - xs[1]*ys[end] +
        sum([xs[i]*ys[i+1]-xs[i+1]*ys[i] for i=1:(size(vertices,2)-1)]))/2
end

@doc """
    function sortpts2D(pts)

Calculate the permutation vector that sorts 2D Cartesian points counterclockwise with
    respect to the average of the points.

# Arguments
- `pts::AbstractMatrix{<:Real}`: Cartesian points in 2D.

# Returns
- `perm::AbstractVector{<:Real}`: the permutation vector that orders the points
    clockwise or counterclockwise.
```
"""
function sortpts2D(pts::AbstractMatrix{<:Real})
    c = sum(pts,dims=2)/size(pts,2)
    angles=zeros(size(pts,2))
    for i=1:size(pts,2)
        (x,y)=pts[:,i] - c
        angles[i] = atan(y,x)
        # if y < 0 angles[i] += 2π end
    end
    perm = sortperm(angles)
    return perm
end

@doc """
    function sortpts_perm(pts)

Calculate the permutation vector that sorts Cartesian points embedded in 3D that
    lie on a plane (counter)clockwise with respect to the average of all points.

# Arguments
- `pts::AbstractMatrix{<:Real}`: Cartesian points embedded in 3D that all lie
    on a plane. The points are columns of a matrix.

# Returns
- `::AbstractVector{<:Real}`: the permutation vector that orders the points
    clockwise or counterclockwise.

# Examples
```jldoctest
import SymmetryReduceBZ.Utilities: sortpts_perm
pts = [0.5 -0.5 0.5; 0.5 -0.5 -0.5; 0.5 0.5 -0.5; 0.5 0.5 0.5]'
perm=sortpts_perm(pts)
pts[:,perm]
# output
3×4 Matrix{Float64}:
  0.5   0.5   0.5  0.5
 -0.5  -0.5   0.5  0.5
  0.5  -0.5  -0.5  0.5
```
"""
function sortpts_perm(pts::AbstractMatrix{<:Real})
    xypts=mapto_xyplane(pts)
    sortpts2D(xypts)
end

@doc """
    unique_points(points;rtol,atol)

Remove duplicate points.

# Arguments
- `points::AbstractMatrix{<:Real}`: the points are columns of a matrix.
- `rtol::Real=sqrt(eps(float(maximum(flatten(points)))))`: a relative tolerance
    for floating point comparisons.
- `atol::Real=1e-9`: an absolute tolerance for floating point comparisons.

# Returns
- `uniquepts::AbstractMatrix{<:Real}`: the unique points as columns of a matrix.

# Examples
```jldoctest
using SymmetryReduceBZ
points=Array([1 2; 2 3; 3 4; 1 2]')
SymmetryReduceBZ.Utilities.unique_points(points)
# output
2×3 Matrix{Float64}:
 1.0  2.0  3.0
 2.0  3.0  4.0
```
"""
function unique_points(points::AbstractMatrix{<:Real};
    rtol::Real=sqrt(eps(float(maximum(flatten(points))))),
    atol::Real=1e-9)::AbstractMatrix
    
    uniquepts=zeros(size(points))
    numpts = 0
    for i=1:size(points,2)
        if !any([isapprox(points[:,i],uniquepts[:,j],rtol=rtol,atol=atol)
                for j=1:numpts])
            numpts += 1
            uniquepts[:,numpts] = points[:,i]
        end
    end
    uniquepts[:,1:numpts]
end

@doc """
    remove_duplicates(points;rtol,atol)

Remove duplicates from an array.

# Arguments
- `points::AbstractVector`: items in a vector, which can be floats or arrays.
- `rtol::Real=sqrt(eps(float(maximum(points))))`: relative tolerance.
- `atol::Real=1e-9`: absolute tolerance. 

# Returns
- `uniquepts::AbstractVector`: an vector with only unique elements. 

# Examples
```jldoctest
import SymmetryReduceBZ.Utilities: remove_duplicates
test = [1.,1.,2,2,]
remove_duplicates(test)
# output
2-element Vector{Any}:
 1.0
 2.0
```
"""
function remove_duplicates(points::AbstractVector;
    rtol::Real=sqrt(eps(float(maximum(flatten(points))))),
    atol::Real=1e-9)::AbstractVector
    uniquepts=Array{Any}(undef, length(points))
    uniquepts[1] = points[1]
    npts = 1
    for i=2:length(points)
        pt=points[i]
        if !any([isapprox(pt,uniquepts[i],rtol=rtol,atol=atol) for i=1:npts])
            npts += 1
            uniquepts[npts] = pt
        end
    end
    uniquepts[1:npts]
end

@doc """
    points₋in₋ball(points,radius,offset,rtol=sqrt(eps(float(radius))),atol=1e-9)

Calculate the points within a ball (circle, sphere, ...).

# Arguments
- `points::AbstractMatrix{<:Real}`: points in Cartesian coordinates as columns of a matrix.
- `radius::Real`: the radius of the ball.
- `offset::AbstractVector{<:Real}`: the location of the center of the ball in Cartesian coordinates.
- `rtol::Real=sqrt(eps(float(radius)))`: a relative tolerance for floating point comparisons.
- `atol::Real=1e-9`: an absolute tolerance.

# Returns
- `ball_points::AbstractVector{<:Int}`: the indices of points in `points` within the ball.

# Examples
```jldoctest
import SymmetryReduceBZ.Utilities: points₋in₋ball
points = [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.25 0.3 0.35 0.4 0.45 0.5 0.3 0.35 0.4 0.45 0.5 0.35 0.4 0.45 0.5 0.4 0.45 0.5 0.45 0.5 0.5; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.1 0.15 0.15 0.15 0.15 0.15 0.15 0.15 0.15 0.2 0.2 0.2 0.2 0.2 0.2 0.2 0.25 0.25 0.25 0.25 0.25 0.25 0.3 0.3 0.3 0.3 0.3 0.35 0.35 0.35 0.35 0.4 0.4 0.4 0.45 0.45 0.5]
radius = 0.1
offset = [0,0]
points₋in₋ball(points,radius,offset)
# output
4-element Vector{Int64}:
  1
  2
  3
 12
```
"""
function points₋in₋ball(points::AbstractMatrix{<:Real},radius::Real,
    offset::AbstractVector{<:Real};rtol::Real=sqrt(eps(float(radius))),
    atol::Real=1e-9)::AbstractVector{<:Int}

    ball_points = zeros(Int,size(points,2))
    count = 0
    for i=1:size(points,2)
        if (norm(points[:,i] - offset) < radius) || 
            isapprox(norm(points[:,i] - offset),radius,rtol=rtol,atol=atol)
            count+=1
            ball_points[count] = i
        end
    end
    ball_points[1:count]
end

end # module
