```@meta
CurrentModule = AbstractAlgebra
DocTestSetup = AbstractAlgebra.doctestsetup()
```

# Multivariate Polynomial Ring Interface

Multivariate polynomial rings are supported in AbstractAlgebra.jl, and in addition to
the standard Ring interface, numerous additional functions are provided.

Unlike other kinds of rings, even complex operations such as GCD depend heavily on the
multivariate representation. Therefore AbstractAlgebra.jl cannot provide much in the
way of additional functionality to external multivariate implementations.

This means that external libraries must be able to implement their multivariate
formats in whatever way they see fit. The required interface here should be implemented,
even if it is not optimal. But it can be extended, either by implementing one of the
optional interfaces, or by extending the required interface in some other way.

Naturally, any multivariate polynomial ring implementation provides the full Ring
interface, in order to be treated as a ring for the sake of AbstractAlgebra.jl.

Considerations which make it impossible for AbstractAlgebra.jl to provide generic
functionality on top of an arbitrary multivariate module include:

  * orderings (lexical, degree, weighted, block, arbitrary)
  * sparse or dense representation
  * distributed or recursive representation
  * packed or unpacked exponents
  * exponent bounds (and whether adaptive or not)
  * random access or iterators
  * whether monomials and polynomials have the same type
  * whether special cache aware data structures such as Geobuckets are used

## Types and parents

AbstractAlgebra.jl provides two abstract types for multivariate polynomial rings and
their elements:

  * `MPolyRing{T}` is the abstract type for multivariate polynomial ring parent types
  * `MPolyRingElem{T}` is the abstract type for multivariate polynomial types

We have that `MPolyRing{T} <: Ring` and
`MPolyRingElem{T} <: RingElem`.

Note that both abstract types are parameterised. The type `T` should usually be the type
of elements of the coefficient ring of the polynomial ring. For example, in the case of
$\mathbb{Z}[x, y]$ the type `T` would be the type of an integer, e.g. `BigInt`.

Multivariate polynomial rings should be made unique on the system by caching parent
objects (unless an optional `cache` parameter is set to `false`). Multivariate
polynomial rings should at least be distinguished based on their base (coefficient)
ring and number of variables. But if they have the same base ring, symbols (for their
variables/generators) and ordering, they should certainly have the same parent object.

See `src/generic/GenericTypes.jl` for an example of how to implement such a cache (which
usually makes use of a dictionary).

## Required functionality for multivariate polynomials

In addition to the required functionality for the Ring interface, the Multivariate
Polynomial interface has the following required functions.

We suppose that `R` is a fictitious base ring (coefficient ring) and that `S` is a
multivariate polynomial ring over `R` (i.e. $S = R[x, y, \ldots]$) with parent object
`S` of type `MyMPolyRing{T}`. We also assume the polynomials in the ring have type
`MyMPoly{T}`, where `T` is the type of elements of the base (coefficient) ring.

Of course, in practice these types may not be parameterised, but we use parameterised
types here to make the interface clearer.

Note that the type `T` must (transitively) belong to the abstract type `RingElem` or
more generally the union type `RingElement` which includes the Julia integer, rational
and floating point types.

### Constructors

To construct a multivariate polynomial ring, there is the following constructor.

```@docs; canonical=false
polynomial_ring(R::Ring, s::Vector{Symbol})
```

Polynomials in a given ring can be constructed using the generators and basic
polynomial arithmetic. However, this is inefficient and the following build
context is provided for building polynomials term-by-term. It assumes the
polynomial data type is random access, and so the constructor functions must
be reimplemented for all other types of polynomials.

```julia
MPolyBuildCtx(R::MPolyRing)
```

Return a build context for creating polynomials in the given polynomial ring.

```julia
push_term!(M::MPolyBuildCtx, c::RingElem, v::Vector{Int})
```

Add the term with coefficient $c$ and exponent vector $v$ to the polynomial
under construction in the build context $M$.

```julia
finish(M::MPolyBuildCtx)
```

Finish construction of the polynomial, sort the terms, remove duplicate and
zero terms and return the created polynomial.

### Data type and parent object methods

```julia
symbols(S::MyMPolyRing{T}) where T <: RingElem
```

Return an array of `Symbol`s representing the variables (generators) of the polynomial
ring. Note that these are `Symbol`s not `String`s, though their string values will
usually be used when printing polynomials.

```julia
number_of_variables(f::MyMPolyRing{T}) where T <: RingElem
```

Return the number of variables of the polynomial ring.

```julia
gens(S::MyMPolyRing{T}) where T <: RingElem
```

Return an array of all the generators (variables) of the given polynomial ring
(as polynomials).

The first entry in the array will be the variable with most significance with
respect to the ordering.

```julia
gen(S::MyMPolyRing{T}, i::Int) where T <: RingElem
```

Return the $i$-th generator (variable) of the given polynomial ring (as a
polynomial).

```julia
internal_ordering(S::MyMPolyRing{T})
```

Return the ordering of the given polynomial ring as a symbol. Supported values currently
include `:lex`, `:deglex` and `:degrevlex`.

### Basic manipulation of rings and elements

```julia
length(f::MyMPoly{T}) where T <: RingElem
```

Return the number of nonzero terms of the given polynomial. The length of the zero
polynomial is defined to be $0$. The return value should be of type `Int`.

```julia
degrees(f::MyMPoly{T}) where T <: RingElem
```

Return an array of the degrees of the polynomial $f$ in each of the variables.

```julia
total_degree(f::MyMPoly{T}) where T <: RingElem
```

Return the total degree of the polynomial $f$, i.e. the highest sum of
exponents occurring in any term of $f$.

```julia
is_gen(x::MyMPoly{T}) where T <: RingElem
```

Return `true` if $x$ is a generator of the polynomial ring.

```julia
coefficients(p::MyMPoly{T}) where T <: RingElem
```

Return an iterator for the coefficients of the polynomial $p$, starting
with the coefficient of the most significant term with respect to the
ordering. Generic code will provide this function automatically for
random access polynomials that implement the `coeff` function.

```julia
monomials(p::MyMPoly{T}) where T <: RingElem
```

Return an iterator for the monomials of the polynomial $p$, starting with
the monomial of the most significant term with respect to the ordering.
Monomials in AbstractAlgebra are defined to have coefficient $1$. See the
function `terms` if you also require the coefficients, however note that
only monomials can be compared. Generic code will provide this function
automatically for random access polynomials that implement the `monomial`
function.

```julia
terms(p::MyMPoly{T}) where T <: RingElem
```

Return an iterator for the terms of the polynomial $p$, starting with
the most significant term with respect to the ordering. Terms in
AbstractAlgebra include the coefficient. Generic code will provide this
function automatically for random access polynomials that implement the
`term` function.

```julia
exponent_vectors(a::MyMPoly{T}) where T <: RingElement
```

Return an iterator for the exponent vectors for each of the terms of the
polynomial starting with the most significant term with respect to the
ordering. Each exponent vector is an array of `Int`s, one for each
variable, in the order given when the polynomial ring was created.
Generic code will provide this function automatically for random access
polynomials that implement the `exponent_vector` function.

### Exact division

For any ring that implements exact division, the following can be implemented.

```julia
divexact(f::MyMPoly{T}, g::MyMPoly{T}) where T <: RingElem
```

Return the exact quotient of $f$ by $g$ if it exists, otherwise throw an error.

```julia
divides(f::MyMPoly{T}, g::MyMPoly{T}) where T <: RingElem
```

Return a tuple `(flag, q)` where `flag` is `true` if $g$ divides $f$, in which case
$q$ will be the exact quotient, or `flag` is false and $q$ is set to zero.

```julia
remove(f::MyMPoly{T}, g::MyMPoly{T}) where T <: RingElem
```

Return a tuple $(v, q)$ such that the highest power of $g$ that divides $f$ is $g^v$
and the cofactor is $q$.

```julia
valuation(f::MyMPoly{T}, g::MyMPoly{T}) where T <: RingElem
```

Return $v$ such that the highest power of $g$ that divides $f$ is $g^v$.

### Ad hoc exact division

For any ring that implements exact division, the following can be implemented.

```julia
divexact(f::MyMPoly{T}, c::Integer) where T <: RingElem
divexact(f::MyMPoly{T}, c::Rational) where T <: RingElem
divexact(f::MyMPoly{T}, c::T) where T <: RingElem
```

Divide the polynomial exactly by the constant $c$.

### Euclidean division

Although multivariate polynomial rings are not in general Euclidean, it is possible to
define a quotient with remainder function that depends on the polynomial ordering in
the case that the quotient ring is a field or a Euclidean domain. In the case that
a polynomial $g$ divides a polynomial $f$, the result no longer depends on the ordering
and the remainder is zero, with the quotient agreeing with the exact quotient.

```julia
divrem(f::MyMPoly{T}, g::MyMPoly{T}) where T <: RingElem
```

Return a tuple $(q, r)$ such that $f = qg + r$, where the coefficients of terms of
$r$ whose monomials are divisible by the leading monomial of $g$ are reduced modulo the
leading coefficient of $g$ (according to the Euclidean function on the coefficients).

Note that the result of this function depends on the ordering of the polynomial ring.

```julia
div(f::MyMPoly{T}, g::MyMPoly{T}) where T <: RingElem
```

As per the `divrem` function, but returning the quotient only. Especially when the
quotient happens to be exact, this function can be exceedingly fast.

### GCD

In cases where there is a meaningful Euclidean structure on the coefficient ring, it is
possible to compute the GCD of multivariate polynomials.

```julia
gcd(f::MyMPoly{T}, g::MyMPoly{T}) where T <: RingElem
```

Return a greatest common divisor of $f$ and $g$.

### Square root

Over rings for which an exact square root is available, it is possible to take
the square root of a polynomial or test whether it is a square.

```julia
sqrt(f::MyMPoly{T}, check::Bool=true) where T <: RingElem
```

Return the square root of the polynomial $f$ and raise an exception if it is
not a square. If `check` is set to `false`, the input is assumed to be a
perfect square and this assumption is not fully checked. This can be
significantly faster.

```julia
is_square(::MyMPoly{T}) where T <: RingElem
```

Return `true` if $f$ is a square.

## Interface for sparse distributed, random access multivariates

The following additional functions should be implemented by libraries that provide a
sparse distributed polynomial format, stored in a representation for which terms can
be accessed in constant time (e.g. where arrays are used to store coefficients and
exponent vectors).

### Sparse distributed, random access constructors

In addition to the standard constructors, the following constructor, taking arrays of
coefficients and exponent vectors, should be provided.

```julia
(S::MyMPolyRing{T})(A::Vector{T}, m::Vector{Vector{Int}}) where T <: RingElem
```

Create the polynomial in the given ring with nonzero coefficients specified by
the elements of $A$ and corresponding exponent vectors given by the elements of
$m$.

There is no assumption about coefficients being nonzero or terms being in order
or unique. Zero terms are removed by the function, duplicate terms are combined
(added) and the terms are sorted so that they are in the correct order.

Each exponent vector uses a separate integer for each exponent field, the first
of which should be the exponent for the most significant variable with respect
to the ordering. All exponents must be non-negative.

A library may also optionally provide an interface that makes use of `BigInt`
(or any other big integer type) for exponents instead of `Int`.

### Sparse distributed, random access basic manipulation

```julia
coeff(f::MyMPoly{T}, n::Int) where T <: RingElem
```

Return the coefficient of the $n$-th term of $f$. The first term should be the most
significant term with respect to the ordering.

```julia
coeff(a::MyMPoly{T}, exps::Vector{Int}) where T <: RingElement
```

Return the coefficient of the term with the given exponent vector, or zero
if there is no such term.

```julia
monomial(f::MyMPoly{T}, n::Int) where T <: RingElem
monomial!(m::MyMPoly{T}, f::MyMPoly{T}, n::Int) where T <: RingElem
```

Return the $n$-th monomial of $f$ or set $m$ to the $n$-th monomial of $f$,
respectively. The first monomial should be the most significant term with
respect to the ordering. Monomials have coefficient $1$ in AbstractAlgebra.
See the function `term` if you also require the coefficient, however, note
that only monomials can be compared.

```julia
term(f::MyMPoly{T}, n::Int) where T <: RingElem
```

Return the $n$-th term of $f$. The first term should be the one whose
monomial is most significant with respect to the ordering.

```julia
exponent(f::MyMPoly{T}, i::Int, j::Int) where T <: RingElem
```

Return the exponent of the $j$-th variable in the $i$-th term of the polynomial
$f$. The first term is the one with whose monomial is most significant with
respect to the ordering.

```julia
exponent_vector(a::MyMPoly{T}, i::Int) where T <: RingElement
```

Return a vector of exponents, corresponding to the exponent vector of the
i-th term of the polynomial. Term numbering begins at $1$ and the exponents
are given in the order of the variables for the ring, as supplied when the
ring was created.

```julia
setcoeff!(a::MyMPoly, exps::Vector{Int}, c::S) where S <: RingElement
```

Set the coefficient of the term with the given exponent vector to the given
value $c$. If no such term exists (and $c \neq 0$), one will be inserted. This
function takes $O(\log n)$ operations if a term with the given exponent already
exists and $c \neq 0$, or if the term is inserted at the end of the polynomial.
Otherwise it can take $O(n)$ operations in the worst case. This function must
return the modified polynomial.

### Unsafe functions

The following functions must be provided, but are considered unsafe, as they
may leave the polynomials in an inconsistent state and they mutate their
inputs. As usual, such functions should only be applied on polynomials that
have no references elsewhere in the system and are mainly intended to be used
in carefully written library code, rather than by users.

Users should instead build polynomials using the constructors described above.

```julia
fit!(f::MyMPoly{T}, n::Int) where T <: RingElem
```

Ensure that the polynomial $f$ internally has space for $n$ nonzero terms. This
function must mutate the function in-place if it is mutable. It does not return
the mutated polynomial. Immutable types can still be supported by defining this
function to do nothing.

```julia
setcoeff!(a::MyMPoly{T}, i::Int, c::T) where T <: RingElement
setcoeff!(a::MyMPoly{T}, i::Int, c::U) where {T <: RingElement, U <: Integer}
```

Set the $i$-th coefficient of the polynomial $a$ to $c$. No check is performed
on the index $i$ or for $c = 0$. It may be necessary to call
`combine_like_terms` after calls to this function, to remove zero terms. The
function must return the modified polynomial.

```julia
combine_like_terms!(a::MyMPoly{T}) where T <: RingElement
```

Remove zero terms and combine any adjacent terms with the same exponent
vector (by adding them). It is assumed that all the exponent vectors are
already in the correct order with respect to the ordering. The function
must return the resulting polynomial.

```julia
set_exponent_vector!(a::MyMPoly{T}, i::Int, exps::Vector{Int}) where T <: RingElement
```

Set the $i$-th exponent vector to the given exponent vector. No check is
performed on the index $i$, which is assumed to be valid (or that the
polynomial has enough space allocated). No sorting of exponents is performed
by this function. To sort the terms after setting any number of exponents
with this function, run the `sort_terms!` function. The function must return
the modified polynomial.

```julia
sort_terms!(a::MyMPoly{T}) where {T <: RingElement}
```

Sort the terms of the given polynomial according to the polynomial ring
ordering. Zero terms and duplicate exponents are ignored. To deal with those
call `combine_like_terms`. The sorted polynomial must be returned by the
function.

## Optional functionality for multivariate polynomials

The following functions can optionally be implemented for multivariate
polynomial types.

### Reduction by an ideal

```julia
divrem(f::MyMPoly{T}, G::Vector{MyMPoly{T}}) where T <: RingElem
```

As per the `divrem` function above, except that each term of $r$ starting with the
most significant term, is reduced modulo the leading terms of each of the polynomials
in the array $G$ for which the leading monomial is a divisor.

A tuple $(Q, r)$ is returned from the function, where $Q$ is an array of polynomials
of the same length as $G$, and such that $f = r + \sum Q[i]G[i]$.

The result is again dependent on the ordering in general, but if the polynomials in $G$
are over a field and the reduced generators of a Groebner basis, then the result is
unique.

### Evaluation

```julia
evaluate(a::MyMPoly{T}, A::Vector{T}) where T <: RingElem
```

Evaluate the polynomial at the given values in the coefficient ring of the
polynomial. The result should be an element of the coefficient ring.

```julia
evaluate(f::MyMPoly{T}, A::Vector{U}) where {T <: RingElem, U <: Integer}
```

Evaluate the polynomial $f$ at the values specified by the entries of the array $A$.

```julia
(a::MyMPoly{T})(vals::Union{NCRingElem, RingElement}...) where T <: RingElement
```

Evaluate the polynomial at the given arguments. This provides functional
notation for polynomial evaluation, i.e. $f(a, b, c)$. It must be defined
for each supported polynomial type (Julia does not allow functional
notation to be defined for an abstract type).

The code for this function in MPoly.jl can be used when implementing this
as it provides the most general possible evaluation, which is much more
general than the case of evaluation at elements of the same ring.

The evaluation should succeed for any set of values for which a
multiplication is defined with the product of a coefficient and all the
values before it.

!!! note

    The values at which a polynomial is evaluated may be in non-commutative
    rings. Products are performed in the order of the variables in the
    polynomial ring that the polynomial belongs to, preceded by a
    multiplication by the coefficient on the left.

### Derivations

The following function allows to compute derivations of multivariate
polynomials of type MPoly.

```julia
derivative(f::MyMPoly{T}, j::Int) where T <: RingElem
```

Compute the derivative of $f$ with respect to the $j$-th variable of the
polynomial ring.

