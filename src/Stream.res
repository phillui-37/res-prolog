/***
  A minimal lazy stream used by the solver to model Prolog-style
  backtracking. Each cell is produced on demand so consumers can stop
  enumerating after the first N answers without exploring the rest of
  the search tree.
*/

type rec t<'a> = unit => cell<'a>
and cell<'a> = Nil | Cons('a, t<'a>)

let nil: t<'a> = () => Nil

let cons = (x, rest) => () => Cons(x, rest)

let single = x => () => Cons(x, nil)

let rec append = (s1: t<'a>, s2: t<'a>): t<'a> =>
  () =>
    switch s1() {
    | Nil => s2()
    | Cons(x, rest) => Cons(x, append(rest, s2))
    }

let rec flatMap = (s: t<'a>, f: 'a => t<'b>): t<'b> =>
  () =>
    switch s() {
    | Nil => Nil
    | Cons(x, rest) => append(f(x), flatMap(rest, f))()
    }

let rec take = (s: t<'a>, n: int): list<'a> =>
  if n <= 0 {
    list{}
  } else {
    switch s() {
    | Nil => list{}
    | Cons(x, rest) => list{x, ...take(rest, n - 1)}
    }
  }

let rec toList = (s: t<'a>): list<'a> =>
  switch s() {
  | Nil => list{}
  | Cons(x, rest) => list{x, ...toList(rest)}
  }

let rec ofList = (xs: list<'a>): t<'a> =>
  () =>
    switch xs {
    | list{} => Nil
    | list{x, ...rest} => Cons(x, ofList(rest))
    }

let map = (s: t<'a>, f: 'a => 'b): t<'b> => flatMap(s, x => single(f(x)))
