import std/sequtils
import std/sets

import compiler / [ modulegraphs, lineinfos, renderer, ast ]

import dust/spec
import dust/hashing

proc next*(remains: var Remains; n: PNode; next: var PNode): bool =
  let h = hashNode(n)
  if h notin remains:
    remains.add(n, h)
    assert len(remains) > 0

  result = len(remains) > 0
  if result:
    next = pop(remains)
    assert not next.isNil
