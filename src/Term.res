/***
  Core term representation for the logical framework.

  Design
  ======
  All identifiers (atom names, compound/predicate names, variable names)
  are kept *polymorphic* in this module so callers can drive the model with
  ReScript's type system instead of strings. Polymorphic variants are the
  natural fit:

      let p = Compound(#parent, list{Atom(#tom), Atom(#bob)})

  No string interpolation is used anywhere. Identifiers must come from the
  type system; typos surface as compile-time errors.

  Variables
  ---------
  A variable id is either:
    - `UserVar(name)` — supplied by user code (e.g. `#X`)
    - `FreshVar(int)` — generated internally by the solver while renaming
      clause variables, so user names cannot clash with intermediate state.
*/

type rec term<'name, 'v> =
  | Atom('name)
  | Int(int)
  | Float(float)
  | Var(varId<'v>)
  | Compound('name, list<term<'name, 'v>>)
and varId<'v> =
  | UserVar('v)
  | FreshVar(int)

type clause<'name, 'v> = {
  head: term<'name, 'v>,
  body: list<term<'name, 'v>>,
}

type database<'name, 'v> = list<clause<'name, 'v>>

/* --- Constructors / smart helpers --- */

let atom = n => Atom(n)
let int = i => Int(i)
let float_ = f => Float(f)
let var = v => Var(UserVar(v))
let compound = (n, args) => Compound(n, args)

let fact = head => {head, body: list{}}
let rule = (head, body) => {head, body}

/* --- Variable utilities --- */

let rec collectVars = (t: term<'n, 'v>): list<varId<'v>> =>
  switch t {
  | Var(v) => list{v}
  | Compound(_, args) =>
    args->List.reduce(list{}, (acc, t) => List.concat(acc, collectVars(t)))
  | Atom(_) | Int(_) | Float(_) => list{}
  }

let dedupVars = (vs: list<varId<'v>>): list<varId<'v>> => {
  let rec aux = (acc, xs) =>
    switch xs {
    | list{} => List.reverse(acc)
    | list{x, ...rest} =>
      if List.some(acc, y => y == x) {
        aux(acc, rest)
      } else {
        aux(list{x, ...acc}, rest)
      }
    }
  aux(list{}, vs)
}

let clauseVars = (c: clause<'n, 'v>): list<varId<'v>> =>
  dedupVars(List.concat(collectVars(c.head), c.body->List.reduce(list{}, (acc, t) =>
        List.concat(acc, collectVars(t))
      )))
