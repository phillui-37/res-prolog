/***
  Family / ancestor example, mirroring the F# reference.

  Everything is type-driven: `#parent`, `#tom`, `#X`, etc. are polymorphic
  variants. ReScript will infer their union types and reject typos.
*/

open DSL

/* parent/2 facts */
let parentFact = (a, b) => fact(compound(#parent, list{atom(a), atom(b)}))

let family = list{
  parentFact(#tom, #bob),
  parentFact(#tom, #liz),
  parentFact(#bob, #ann),
  parentFact(#bob, #pat),
  parentFact(#pat, #jim),
  /* ancestor(X, Y) :- parent(X, Y). */
  rule(
    compound(#ancestor, list{var(#X), var(#Y)}),
    list{compound(#parent, list{var(#X), var(#Y)})},
  ),
  /* ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y). */
  rule(
    compound(#ancestor, list{var(#X), var(#Y)}),
    list{
      compound(#parent, list{var(#X), var(#Z)}),
      compound(#ancestor, list{var(#Z), var(#Y)}),
    },
  ),
}

/* "Show" only for example output — not used by the framework itself. */
let showName = (n): string =>
  switch n {
  | #parent => "parent"
  | #ancestor => "ancestor"
  | #tom => "tom"
  | #bob => "bob"
  | #liz => "liz"
  | #ann => "ann"
  | #pat => "pat"
  | #jim => "jim"
  }

let rec showTerm = (t): string =>
  switch t {
  | Atom(n) => showName(n)
  | Int(i) => Int.toString(i)
  | Float(f) => Float.toString(f)
  | Var(UserVar(_)) => "_"
  | Var(FreshVar(i)) => "_G" ++ Int.toString(i)
  | Compound(n, args) =>
    showName(n) ++ "(" ++ args->List.map(showTerm)->List.toArray->Array.join(", ") ++ ")"
  }

/* Children of tom. */
let children = query(family, compound(#parent, list{atom(#tom), var(#Child)}), #Child)
Console.log("Children of tom:")
children->List.forEach(t => Console.log("  " ++ showTerm(t)))

/* All ancestors of jim. */
let ancestors = query(family, compound(#ancestor, list{var(#A), atom(#jim)}), #A)
Console.log("Ancestors of jim:")
ancestors->List.forEach(t => Console.log("  " ++ showTerm(t)))

/* All descendants of tom. */
let descendants = query(family, compound(#ancestor, list{atom(#tom), var(#D)}), #D)
Console.log("Descendants of tom:")
descendants->List.forEach(t => Console.log("  " ++ showTerm(t)))
