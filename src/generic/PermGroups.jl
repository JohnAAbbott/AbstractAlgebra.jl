###############################################################################
#
#   PermGroups.jl - Permutation groups
#
###############################################################################

###############################################################################
#
#   Type and parent object methods
#
###############################################################################

parent_type(::Type{Perm{T}}) where T = SymmetricGroup{T}

parent(g::Perm{T}) where T = SymmetricGroup(T(length(g.d)))

check_parent(g::Perm, h::Perm) = length(g.d) == length(h.d) ||
   throw(ArgumentError("incompatible permutation groups"))

###############################################################################
#
#   Low-level manipulation
#
###############################################################################

# hash(Perm) = 0x0d9939c64ab650ca
# note: we don't use hash(g.d, h), as it's unnecessarily slow for this use-case
Base.hash(g::Perm, h::UInt) = foldl((h, x) -> hash(x, h), g.d,
                                    init = hash(0x0d9939c64ab650ca, h))

Base.deepcopy_internal(g::Perm, dict::IdDict) =
   Perm(Base.deepcopy_internal(g.d, dict), false)

function getindex(g::Perm, n::Integer)
   return g.d[n]
end

function setindex!(g::Perm, v::Integer, n::Integer)
   g.modified = true
   g.d[n] = v
   return g
end

Base.promote_rule(::Type{Perm{I}}, ::Type{Perm{J}}) where {I,J} =
   Perm{promote_type(I,J)}

convert(::Type{Perm{T}}, p::Perm) where T = Perm(convert(Vector{T}, p.d), false)

Vector{T}(p::Perm{T}) where {T} = p.d

function Base.similar(p::Perm{T}, ::Type{S}=T) where {T, S<:Integer}
   p = Perm(similar(p.d, S), false)
   p.modified = true
   return p
end

###############################################################################
#
#   Basic functions
#
###############################################################################

@doc raw"""
    parity(g::Perm)

Return the parity of the given permutation, i.e. the parity of the number of
transpositions in any decomposition of `g` into transpositions.

`parity` returns $1$ if the number is odd and $0$ otherwise. `parity` uses
cycle decomposition of `g` if already available, but will not compute
it on demand. Since cycle structure is cached in `g` you may call
`cycles(g)` before calling `parity`.

# Examples
```jldoctest
julia> g = Perm([3,4,1,2,5])
(1,3)(2,4)

julia> parity(g)
0

julia> g = Perm([3,4,5,2,1,6])
(1,3,5)(2,4)

julia> parity(g)
1
```
"""
function parity(g::Perm{T}) where T
   if isdefined(g, :cycles) && !g.modified
      return T(sum([(length(c)+1)%2 for c in cycles(g)])%2)
   end
   to_visit = trues(size(g.d))
   parity = false
   k = 1
   @inbounds while true
      k = findnext(to_visit, k)
      k !== nothing || break
      to_visit[k] = false
      next = g[k]
      while next != k
         parity = !parity
         to_visit[next] = false
         next = g[next]
      end
   end
   return T(parity)
end

@doc raw"""
    sign(g::Perm)

Return the sign of a permutation.

`sign` returns $1$ if `g` is even and $-1$ if `g` is odd. `sign` represents
the homomorphism from the permutation group to the unit group of $\mathbb{Z}$
whose kernel is the alternating group.

# Examples
```jldoctest
julia> g = Perm([3,4,1,2,5])
(1,3)(2,4)

julia> sign(g)
1

julia> g = Perm([3,4,5,2,1,6])
(1,3,5)(2,4)

julia> sign(g)
-1
```
"""
sign(g::Perm{T}) where T = (-one(T))^parity(g)

###############################################################################
#
#   Iterator protocol for CycleDec
#
###############################################################################

function Base.iterate(cd::CycleDec)
   this = cd.cptrs[1]
   next = cd.cptrs[2]
   return (view(cd.ccycles, this:next-1), 2)
end

function Base.iterate(cd::CycleDec, state)
   if state > cd.n
      return nothing
   end

   this = cd.cptrs[state]
   next = cd.cptrs[state + 1]

   return (view(cd.ccycles, this:next-1), state + 1)
end

function Base.getindex(cd::CycleDec, n::Int)
   1 <= n <= length(cd) || throw(BoundsError([cd.cptrs], n+1))
   return cd.ccycles[cd.cptrs[n]:cd.cptrs[n+1]-1]
end

Base.getindex(cd::CycleDec, i::Number) = cd[convert(Int, i)]
Base.getindex(cd::CycleDec, I) = [cd[i] for i in I]

Base.length(cd::CycleDec) = cd.n
Base.lastindex(cd::CycleDec) = cd.n
Base.eltype(::Type{CycleDec{T}}) where T = Vector{T}

function Base.show(io::IO, cd::CycleDec)
   a = [join(c, ",") for c in cd]::Vector{String}
   print(io, "Cycle Decomposition: ("*join(a, ")(")*")")
end

@doc raw"""
    cycles(g::Perm)

Decompose permutation `g` into disjoint cycles.

Return a `CycleDec` object which iterates over disjoint cycles of `g`. The
ordering of cycles is not guaranteed, and the order within each cycle is
computed up to a cyclic permutation.
The cycle decomposition is cached in `g` and used in future computation of
`permtype`, `parity`, `sign`, `order` and `^` (powering).

# Examples
```jldoctest
julia> g = Perm([3,4,5,2,1,6])
(1,3,5)(2,4)

julia> collect(cycles(g))
3-element Vector{Vector{Int64}}:
 [1, 3, 5]
 [2, 4]
 [6]
```
"""
function cycles(g::Perm{T}) where T<:Integer
   if !isdefined(g, :cycles) || g.modified
      ccycles, cptrs = cycledec(g.d)
      g.cycles = CycleDec{T}(ccycles, cptrs, length(cptrs)-1)
      g.modified = false
   end
   return g.cycles
end

function cycledec(v::Vector{T}) where T<:Integer
   to_visit = trues(size(v))
   ccycles = similar(v) # consecutive cycles entries
   cptrs = [1] # pointers to where cycles start
   # ccycles[cptrs[i], cptrs[i+1]-1] contains i-th cycle

   # expected number of cycles - (overestimation of) the harmonic
   sizehint!(cptrs, 5 + ceil(Int, Base.log(length(v) + 1))) # +1 to account for an empty v
   # cptrs[1] = one(T)

   k = 1
   i = 1

   while true
      k = findnext(to_visit, k)
      k !== nothing || break
      to_visit[k] = false
      next = v[k]

      ccycles[i] = T(k)
      i += 1
      while next != k
         ccycles[i] = next
         to_visit[next] = false
         next = v[next]
         i += 1
      end
      push!(cptrs, i)
   end
   return ccycles, cptrs
end

@doc raw"""
    permtype(g::Perm)

Return the type of permutation `g`, i.e. lengths of disjoint cycles in cycle
decomposition of `g`.

The lengths are sorted in decreasing order by default. `permtype(g)` fully
determines the conjugacy class of `g`.

# Examples
```jldoctest
julia> g = Perm([3,4,5,2,1,6])
(1,3,5)(2,4)

julia> permtype(g)
3-element Vector{Int64}:
 3
 2
 1

julia> e = one(g)
()

julia> permtype(e)
6-element Vector{Int64}:
 1
 1
 1
 1
 1
 1
```
"""
permtype(g::Perm) = sort!(diff(cycles(g).cptrs), rev=true)

###############################################################################
#
#   String I/O
#
###############################################################################

function show(io::IO, G::SymmetricGroup)
   print(io, "Full symmetric group over $(G.n) elements")
end

mutable struct PermDisplayStyle
   format::Symbol
end

const _permdisplaystyle = PermDisplayStyle(:cycles)

@doc raw"""
    setpermstyle(format::Symbol)

Select the style in which permutations are displayed (in the REPL or in general
as strings). This can be either
* `:array` - as vector of integers whose $n$-th position represents the
  value at $n$), or
* `:cycles` - as, more familiar for mathematicians, decomposition into
  disjoint cycles, where the value at $n$ is represented by the entry
  immediately following $n$ in a cycle (the default).

The difference is purely esthetical.

# Examples
```jldoctest
julia> setpermstyle(:array)
:array

julia> Perm([2,3,1,5,4])
[2, 3, 1, 5, 4]

julia> setpermstyle(:cycles)
:cycles

julia> Perm([2,3,1,5,4])
(1,2,3)(4,5)
```
"""
function setpermstyle(format::Symbol)
   if format in (:array, :cycles)
      _permdisplaystyle.format = format
   else
      throw("Permutations can be displayed only as :array or :cycles.")
   end
   return format
end

function Base.show(io::IO, g::Perm)
   if _permdisplaystyle.format == :array
      print(io, "[" * join(g.d, ", ") * "]")
   elseif _permdisplaystyle.format == :cycles
      _print_perm(io, g)
   end
end

function _print_perm(io::IO, p::Perm, width::Int=last(displaysize(io)))
   @assert width > 3
   if isone(p)
      return print(io, "()")
   else
      cum_length = 0
      for c in cycles(p)
         length(c) == 1 && continue
         cyc = join(c, ",")::String

         if width - cum_length >= length(cyc)+2
            print(io, "(", cyc, ")")
            cum_length += length(cyc)+2
         else
            available = width - cum_length - 3
            print(io, "(", SubString(cyc, 1, available), " …")
            break
         end
      end
   end
end

###############################################################################
#
#   Comparison
#
###############################################################################

@doc raw"""
    ==(g::Perm, h::Perm)

Return `true` if permutations are equal, otherwise return `false`.

Permutations parametrized by different integer types are considered equal if
they define the same permutation in the abstract permutation group.

# Examples
```
julia> g = Perm(Int8[2,3,1])
(1,2,3)

julia> h = perm"(3,1,2)"
(1,2,3)

julia> g == h
true
```
"""
==(g::Perm, h::Perm) = g.d == h.d

@doc raw"""
    ==(G::SymmetricGroup, H::SymmetricGroup)

Return `true` if permutation groups are equal, otherwise return `false`.

Permutation groups on the same number of letters, but parametrized
by different integer types are considered different.

# Examples
```
julia> G = SymmetricGroup(UInt(5))
Permutation group over 5 elements

julia> H = SymmetricGroup(5)
Permutation group over 5 elements

julia> G == H
false
```
"""
==(G::SymmetricGroup, H::SymmetricGroup) = typeof(G) == typeof(H) && G.n == H.n

###############################################################################
#
#   Binary operators
#
###############################################################################
function mul!(out::Perm, g::Perm, h::Perm)
   out = (out === h ? similar(out) : out)
   check_parent(out, g)
   check_parent(g, h)
   @inbounds for i in eachindex(out.d)
      out[i] = h[g[i]]
   end
   return out
end

@doc raw"""
    *(g::Perm, h::Perm)

Return the composition ``h ∘ g`` of two permutations.

This corresponds to the action of permutation group on the set `[1..n]`
**on the right** and follows the convention of GAP.

If `g` and `h` are parametrized by different types, the result is promoted
accordingly.

# Examples
```jldoctest
julia> Perm([2,3,1,4])*Perm([1,3,4,2]) # (1,2,3)*(2,3,4)
(1,3)(2,4)
```
"""
*(g::Perm{T}, h::Perm{T}) where T = mul!(similar(g), g, h)
*(g::Perm{S}, h::Perm{T}) where {S,T} = *(promote(g,h)...)

@doc raw"""
    ^(g::Perm, n::Integer)

Return the $n$-th power of a permutation `g`.

By default `g^n` is computed by cycle decomposition of `g` if `n > 3`.
`Generic.power_by_squaring` provides a different method for powering which
may or may not be faster, depending on the particular case. Due to caching of
the cycle structure, repeated powering of `g` will be faster with the default
method.

# Examples
```jldoctest
julia> g = Perm([2,3,4,5,1])
(1,2,3,4,5)

julia> g^3
(1,4,2,5,3)

julia> g^5
()
```
"""
function ^(g::Perm{T}, n::Integer) where T
   if n < 0
      return inv(g)^-n
   elseif n == 0
      return Perm(T(length(g.d)))
   elseif n == 1
      return deepcopy(g)
   elseif n == 2
      return Perm(g.d[g.d], false)
   elseif n == 3
      return Perm(g.d[g.d[g.d]], false)
   else
      new_perm = similar(g)

      @inbounds for cycle in cycles(g)
         l = length(cycle)
         k = n % l
         for (idx,j) in enumerate(cycle)
            idx += k
            idx = (idx > l ? idx-l : idx)
            new_perm[j] = cycle[idx]
         end
      end
      return new_perm
   end
end

function power_by_squaring(g::Perm{I}, n::Integer) where {I}
   if n < 0
      return inv(g)^-n
   elseif n == 0
      return Perm(I(length(g.d)))
   elseif n == 1
      return deepcopy(g)
   elseif n == 2
      return Perm(g.d[g.d], false)
   elseif n == 3
      return Perm(g.d[g.d[g.d]], false)
   else
      bit = ~((~UInt(0)) >> 1)
      while (UInt(bit) & n) == 0
         bit >>= 1
      end
      cache1 = deepcopy(g.d)
      cache2 = deepcopy(g.d)
      bit >>= 1
      while bit != 0
         cache2 = cache1[cache1]
         cache1 = cache2
         if (UInt(bit) & n) != 0
            cache1 = cache1[g.d]
         end
         bit >>= 1
      end
      return Perm(cache1, false)
   end
end

###############################################################################
#
#   Inversion
#
###############################################################################

@doc raw"""
    Base.inv(g::Perm)

Return the inverse of the given permutation, i.e. the permutation $g^{-1}$
such that $g ∘ g^{-1} = g^{-1} ∘ g$ is the identity permutation.
"""
function Base.inv(g::Perm)
   res = similar(g)
   @inbounds for i in 1:length(res.d)
      res[g[i]] = i
   end
   return res
end

# TODO: See M. Robertson, Inverting Permutations In Place
# n+O(log^2 n) space, O(n*log n) time
function inv!(a::Perm)
   d = similar(a.d)
   @inbounds for i in 1:length(d)
      d[a[i]] = i
   end
   a.d = d
   a.modified = true
   return a
end

###############################################################################
#
#   Iterating over all permutations
#
###############################################################################

@inline Base.iterate(A::AllPerms) = (A.c .= 1; (A.elts, 1))

@inline function Base.iterate(A::AllPerms{<: Integer}, count)
   count >= A.all && return nothing

   k = 0
   n = 1

   @inbounds while true
      if A.c[n] < n
         k = ifelse(isodd(n), 1, A.c[n])
         A.elts[k], A.elts[n] = A.elts[n], A.elts[k]
         A.c[n] += 1
         return A.elts, count + 1
      else
         A.c[n] = 1
         n += 1
      end
   end
end

Base.eltype(::Type{AllPerms{T}}) where T<:Integer = Perm{T}

Base.length(A::AllPerms) = A.all

@doc raw"""
    Generic.elements!(G::SymmetricGroup)

Return an unsafe iterator over all permutations in `G`. Only one permutation
is allocated and then modified in-place using the non-recursive
[Heaps algorithm](https://en.wikipedia.org/wiki/Heap's_algorithm).

Note: you need to explicitly copy permutations intended to be stored or
modified.

# Examples
```jldoctest
julia> elts = Generic.elements!(SymmetricGroup(5));


julia> length(elts)
120

julia> for p in Generic.elements!(SymmetricGroup(3))
         println(p)
       end
()
(1,2)
(1,3,2)
(2,3)
(1,2,3)
(1,3)

julia> A = collect(Generic.elements!(SymmetricGroup(3))); A
6-element Vector{Perm{Int64}}:
 (1,3)
 (1,3)
 (1,3)
 (1,3)
 (1,3)
 (1,3)

julia> unique(A)
1-element Vector{Perm{Int64}}:
 (1,3)
```
"""
elements!(G::SymmetricGroup)= (p for p in AllPerms(G.n))

@inline function Base.iterate(G::SymmetricGroup)
   A = AllPerms(G.n)
   a, b = iterate(A)
   return Perm(copy(A.elts.d), false), (A, b)
end

@inline function Base.iterate(G::SymmetricGroup, S)
   A, c = S
   s = iterate(A, c)
   s === nothing && return nothing

   return Perm(copy(A.elts.d), false), (A, last(s))
end

Base.eltype(::Type{SymmetricGroup{T}}) where T = Perm{T}

elem_type(::Type{SymmetricGroup{T}}) where T = Perm{T}

Base.length(G::SymmetricGroup) = order(Int, G)

###############################################################################
#
#   Misc
#
###############################################################################

function gens(G::SymmetricGroup)
   G.n == 1 && return eltype(G)[]
   if G.n == 2
      a = one(G)
      a[1], a[2] = 2, 1
      return [a]
   end
   a, b = one(G), one(G)
   circshift!(a.d, b.d, -1)
   b[1], b[2] = 2, 1
   return [a, b]
end

gen(G::SymmetricGroup, i::Int) = gens(G)[i]

number_of_generators(G::SymmetricGroup) = G.n == 1 ? 0 : G.n == 2 ? 1 : 2

is_finite(G::SymmetricGroup) = true

order(::Type{T}, G::SymmetricGroup) where {T} = convert(T, factorial(T(G.n)))

order(::Type{T}, g::Perm) where {T} =
   convert(T, foldl(lcm, length(c) for c in cycles(g)))

is_abelian(G::SymmetricGroup) = G.n <= 2

@doc raw"""
    matrix_repr(a::Perm)

Return the permutation matrix as a sparse matrix representing `a` via natural
embedding of the permutation group into the general linear group over $\mathbb{Z}$.

# Examples
```jldoctest
julia> p = Perm([2,3,1])
(1,2,3)

julia> matrix_repr(p)
3×3 SparseArrays.SparseMatrixCSC{Int64, Int64} with 3 stored entries:
 ⋅  1  ⋅
 ⋅  ⋅  1
 1  ⋅  ⋅

julia> Array(ans)
3×3 Matrix{Int64}:
 0  1  0
 0  0  1
 1  0  0
```
"""
matrix_repr(a::Perm{T}) where T = sparse(collect(T, 1:length(a.d)), a.d, ones(T,length(a.d)))

@doc raw"""
    emb!(result::Perm, p::Perm, V)

Embed permutation `p` into permutation `result` on the indices given by `V`.

This corresponds to the natural embedding of $S_k$ into $S_n$ as the
subgroup permuting points indexed by `V`.

# Examples
```jldoctest
julia> p = Perm([2,1,4,3])
(1,2)(3,4)

julia> Generic.emb!(Perm(collect(1:5)), p, [3,1,4,5])
(1,3)(4,5)
```
"""
function emb!(result::Perm, p::Perm, V)
   result.d[V] = (result.d[V])[p.d]
   return result
end

@doc raw"""
    emb(G::SymmetricGroup, V::Vector{Int}, check::Bool=true)

Return the natural embedding of a permutation group into `G` as the
subgroup permuting points indexed by `V`.

# Examples
```jldoctest
julia> p = Perm([2,3,1])
(1,2,3)

julia> f = Generic.emb(SymmetricGroup(5), [3,2,5]);


julia> f(p)
(2,5,3)
```
"""
function emb(G::SymmetricGroup, V::Vector{Int}, check::Bool=true)
   if check
      @assert length(Base.Set(V)) == length(V)
      @assert all(V .<= G.n)
   end
   return p -> Generic.emb!(one(G), p, V)
end

@doc raw"""
    rand([rng=Random.default_rng(),] G::SymmetricGroup)

Return a random permutation from `G`.
"""
rand(rng::AbstractRNG, rs::Random.SamplerTrivial{SymmetricGroup{T}}) where {T} =
   Perm(randperm!(rng, Vector{T}(undef, rs[].n)), false)

###############################################################################
#
#   Constructor and Parent object call overloads
#
###############################################################################

function perm(a::AbstractVector{<:Integer}, check::Bool = true)
   return Perm(a, check)
end

one(G::SymmetricGroup) = Perm(G.n)
one(g::Perm) = one(parent(g))

Base.isone(g::Perm) = all(i == g[i] for i in eachindex(g.d))

function (G::SymmetricGroup{T})(a::AbstractVector{S}, check::Bool=true) where {S, T}
   if check
      G.n == length(a) || throw("Cannot coerce to $G: lengths differ")
   end
   return Perm(convert(Vector{T}, a), check)
end

function (G::SymmetricGroup{T})(p::Perm{S}, check::Bool=true) where {S, T}
   parent(p) == G && return p
   return Perm(convert(Vector{T}, p.d), check)
end

function (G::SymmetricGroup)(str::String, check::Bool=true)
   return G(cycledec(parse_cycles(str)..., G.n), check)
end

function (G::SymmetricGroup{T})(cdec::CycleDec{T}, check::Bool=true) where T
   if check
      length(cdec.ccycles) == G.n || throw("Can not coerce to $G: lengths differ")
   end

   elt = Perm(G.n)
   for c in cdec
      for i in 1:length(c)-1
         elt[c[i]] = c[i+1]
      end
      elt[c[end]] = c[1]
   end

   elt.cycles = cdec
   return elt
end

###############################################################################
#
#   Parsing strings/GAP output
#
###############################################################################

function parse_cycles(str::AbstractString)
   ccycles = Int[]
   cptrs = Int[1]
   if startswith(str, "Cycle Decomposition: ")
      str = str[22:end]
   end
   if occursin(r"\d\s+\d", str)
      throw(ArgumentError("could not parse string as cycles: $str"))
   end
   str = replace(str, r"\s+" => "")
   str = replace(str, "()" => "")
   cycle_regex = r"\(\d+(,\d+)*\)?"
   parsed_size = 0
   for cycle_str in (m.match for m = eachmatch(cycle_regex, str))
      parsed_size += sizeof(cycle_str)
      cycle = [parse(Int, a) for a in split(cycle_str[2:end-1], ",")]
      append!(ccycles, cycle)
      push!(cptrs, cptrs[end]+length(cycle))
   end
   if parsed_size != sizeof(str)
      throw(ArgumentError("could not parse string as cycles: $str"))
   end
   return ccycles, cptrs
end

function cycledec(ccycles::Vector{Int}, cptrs::Vector{Int}, n::T,
   check::Bool=true) where T
   if check
      if length(ccycles) != 0
         maximum(ccycles) <= n || throw("elts in $ccycles larger than $n")
      end
      length(Set(ccycles)) == length(ccycles) || throw("Non-unique entries in $ccycles")
   end

   if length(ccycles) != n
      sizehint!(ccycles, n)
      to_append = filter(x -> !(x in ccycles), 1:n)
      l = length(ccycles)
      append!(cptrs, l+2:l+length(to_append)+1)
      append!(ccycles, to_append)
   end

   return CycleDec{T}(ccycles, cptrs, length(cptrs)-1)
end

@doc raw"""
    perm"..."

String macro to parse disjoint cycles into `Perm{Int}`.

Strings for the output of GAP could be copied directly into `perm"..."`.
Cycles of length $1$ are not necessary, but can be included. A permutation
of the minimal support is constructed, i.e. the maximal $n$ in the
decomposition determines the parent group $S_n$.

# Examples
```jldoctest
julia> p = perm"(1,3)(2,4)"
(1,3)(2,4)

julia> typeof(p)
Perm{Int64}

julia> parent(p) == SymmetricGroup(4)
true

julia> p = perm"(1,3)(2,4)(10)"
(1,3)(2,4)

julia> parent(p) == SymmetricGroup(10)
true
```
"""
macro perm_str(s)
   c, p = parse_cycles(s)
   if length(c) == 0
      n = 1
   else
      n = maximum(c)
   end
   cdec = cycledec(c, p, n)
   return SymmetricGroup(cdec.cptrs[end]-1)(cdec)
end

###############################################################################
#
#   SymmetricGroup constructor
#
###############################################################################

# handled by inner constructors

##############################################################################
#
#   Irreducible Characters
#
##############################################################################

const _charvalsTable = Dict{Tuple{BitVector,Vector{Int}}, Int}()
const _charvalsTableBig = Dict{Tuple{BitVector,Vector{Int}}, BigInt}()

@doc raw"""
    character(lambda::Partition)

Return the $\lambda$-th irreducible character of permutation group on
`sum(lambda)` symbols. The returned character function is of the following signature:
> `chi(p::Perm[, check::Bool=true]) -> BigInt`
The function checks (if `p` belongs to the appropriate group) can be switched
off by calling `chi(p, false)`. The values computed by $\chi$ are cached in
look-up table.

The computation follows the Murnaghan-Nakayama formula:
$$\chi_\lambda(\sigma) = \sum_{\text{rimhook }\xi\subset \lambda}(-1)^{ll(\lambda\backslash\xi)} \chi_{\lambda \backslash\xi}(\tilde\sigma)$$
where $\lambda\backslash\xi$ denotes the skew diagram of $\lambda$ with $\xi$
removed, $ll$ denotes the leg-length (i.e. number of rows - 1) and
$\tilde\sigma$ is permutation obtained from $\sigma$ by the removal of the
longest cycle.

For more details see e.g. Chapter 2.8 of *Group Theory and Physics* by
S.Sternberg.

# Examples
```jldoctest
julia> G = SymmetricGroup(4)
Full symmetric group over 4 elements

julia> chi = character(Partition([3,1])); # character of the regular representation


julia> chi(one(G))
3

julia> chi(perm"(1,3)(2,4)")
-1
```
"""
function character(lambda::Partition)
   R = partitionseq(lambda)

   char = function(p::Perm, check::Bool=true)
      if check
         sum(lambda) == length(p.d) || throw(ArgumentError("Can't evaluate character on $p : lengths differ."))
      end
      return MN1inner(R, Partition(permtype(p)), 1, _charvalsTableBig)
   end

   return char
end

@doc raw"""
    character(lambda::Partition, p::Perm, check::Bool=true) -> BigInt

Return the value of `lambda`-th irreducible character of the permutation
group on permutation `p`.
"""
function character(lambda::Partition, p::Perm, check::Bool=true)
   if check
      sum(lambda) == length(p.d) || throw("lambda-th irreducible character can be evaluated only on permutations of length $(sum(lambda)).")
   end
   return character(BigInt, lambda, Partition(permtype(p)))
end

function character(::Type{T}, lambda::Partition, p::Perm) where T <: Integer
   return character(T, lambda, Partition(permtype(p)))
end

@doc raw"""
    character(lambda::Partition, mu::Partition, check::Bool=true) -> BigInt

Return the value of `lambda-th` irreducible character on the conjugacy class
represented by partition `mu`.
"""
function character(lambda::Partition, mu::Partition, check::Bool=true)
   if check
      sum(lambda) == sum(mu) || throw("Cannot evaluate $lambda on the conjugacy class of $mu: lengths differ.")
   end
   return character(BigInt, lambda, mu)
end

function character(::Type{BigInt}, lambda::Partition, mu::Partition)
   return MN1inner(partitionseq(lambda), mu, 1, _charvalsTableBig)
end

function character(::Type{T}, lambda::Partition, mu::Partition) where T<:Union{Signed, Unsigned}
   return MN1inner(partitionseq(lambda), mu, 1, _charvalsTable)
end
