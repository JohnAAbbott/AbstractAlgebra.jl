```@meta
CurrentModule = AbstractAlgebra
DocTestSetup = AbstractAlgebra.doctestsetup()
```

# Free Modules and Vector Spaces

AbstractAlgebra allows the construction of free modules of any rank over any
Euclidean ring and the vector space of any dimension over a field. By default
the system considers the free module of a given rank over a given ring or
vector space of given dimension over a field to be unique.

## Generic free module and vector space types

AbstractAlgebra provides generic types for free modules and vector spaces,
via the type `FreeModule{T}` for free modules, where `T`
is the type of the elements of the ring $R$ over which the module is built.

Elements of a free module have type `FreeModuleElem{T}`.

Vector spaces are simply free modules over a field.

The implementation of generic free modules can be found in
`src/generic/FreeModule.jl`.

The free module of a given rank over a given ring is made unique on the
system by caching them (unless an optional `cache` parameter is set to
`false`).

See `src/generic/GenericTypes.jl` for an example of how to implement such a
cache (which usually makes use of a dictionary).

## Abstract types

The type `FreeModule{T}` belongs to `FPModule{T}` and `FreeModuleElem{T}`
to `FPModuleElem{T}`. Here the `FP` prefix stands for finitely presented.

## Functionality for free modules

As well as implementing the entire module interface, free modules provide the
following functionality.

### Constructors

```@docs
free_module(R::Ring, rank::Int)
vector_space(F::Field, dim::Int)
```

Construct the free module/vector space of given rank/dimension.

**Examples**

```jldoctest
julia> M = free_module(ZZ, 3)
Free module of rank 3 over integers

julia> V = vector_space(QQ, 2)
Vector space of dimension 2 over rationals

```

### Basic manipulation

```julia
rank(M::Generic.FreeModule{T}) where T <: RingElem
dim(V::Generic.FreeModule{T}) where T <: FieldElem
basis(V::Generic.FreeModule{T}) where T <: FieldElem
```

**Examples**

```jldoctest
julia> M = free_module(ZZ, 3)
Free module of rank 3 over integers

julia> V = vector_space(QQ, 2)
Vector space of dimension 2 over rationals

julia> rank(M)
3

julia> dim(V)
2

julia> basis(V)
2-element Vector{AbstractAlgebra.Generic.FreeModuleElem{Rational{BigInt}}}:
 (1//1, 0//1)
 (0//1, 1//1)
```


