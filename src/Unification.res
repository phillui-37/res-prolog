/***
  Substitutions & Robinson's unification with occurs check.

  A substitution is an association list from variable id to term. We use a
  list (not a hash map) because:
    - it composes naturally (cons new bindings on the front);
    - sizes are typically tiny per goal;
    - structural equality on `varId` works without needing a hashable
      witness for the polymorphic name parameter.
*/

open Term

type substitution<'name, 'v> = list<(varId<'v>, term<'name, 'v>)>

let empty: substitution<'n, 'v> = list{}

let rec lookup = (s: substitution<'n, 'v>, v: varId<'v>): option<term<'n, 'v>> =>
  switch s {
  | list{} => None
  | list{(v', t), ...rest} => v == v' ? Some(t) : lookup(rest, v)
  }

/* Follow variable chains as far as possible (a.k.a. `walk` in miniKanren). */
let rec walk = (s: substitution<'n, 'v>, t: term<'n, 'v>): term<'n, 'v> =>
  switch t {
  | Var(v) =>
    switch lookup(s, v) {
    | Some(t') => walk(s, t')
    | None => t
    }
  | _ => t
  }

/* Fully resolve a term against the substitution, recursing into compounds. */
let rec resolve = (s: substitution<'n, 'v>, t: term<'n, 'v>): term<'n, 'v> => {
  let t = walk(s, t)
  switch t {
  | Compound(name, args) => Compound(name, args->List.map(a => resolve(s, a)))
  | _ => t
  }
}

/* Occurs check: does variable `v` appear inside term `t` after walking? */
let rec occurs = (s: substitution<'n, 'v>, v: varId<'v>, t: term<'n, 'v>): bool => {
  let t = walk(s, t)
  switch t {
  | Var(v') => v == v'
  | Compound(_, args) => args->List.some(a => occurs(s, v, a))
  | _ => false
  }
}

let extend = (s, v, t) => list{(v, t), ...s}

let rec unify = (
  s: substitution<'n, 'v>,
  t1: term<'n, 'v>,
  t2: term<'n, 'v>,
): option<substitution<'n, 'v>> => {
  let t1 = walk(s, t1)
  let t2 = walk(s, t2)
  switch (t1, t2) {
  | (Var(v1), Var(v2)) if v1 == v2 => Some(s)
  | (Var(v), t) => occurs(s, v, t) ? None : Some(extend(s, v, t))
  | (t, Var(v)) => occurs(s, v, t) ? None : Some(extend(s, v, t))
  | (Atom(a), Atom(b)) => a == b ? Some(s) : None
  | (Int(a), Int(b)) => a == b ? Some(s) : None
  | (Float(a), Float(b)) => a == b ? Some(s) : None
  | (Compound(n1, a1), Compound(n2, a2)) =>
    if n1 == n2 {
      unifyList(s, a1, a2)
    } else {
      None
    }
  | _ => None
  }
}
and unifyList = (
  s: substitution<'n, 'v>,
  xs: list<term<'n, 'v>>,
  ys: list<term<'n, 'v>>,
): option<substitution<'n, 'v>> =>
  switch (xs, ys) {
  | (list{}, list{}) => Some(s)
  | (list{x, ...xr}, list{y, ...yr}) =>
    switch unify(s, x, y) {
    | None => None
    | Some(s') => unifyList(s', xr, yr)
    }
  | _ => None
  }

/* Project the value of a user variable from a substitution, fully resolved. */
let valueOf = (s: substitution<'n, 'v>, v: 'v): option<term<'n, 'v>> =>
  switch lookup(s, UserVar(v)) {
  | None => None
  | Some(t) => Some(resolve(s, t))
  }
