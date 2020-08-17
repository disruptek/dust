import std/strutils
import std/sequtils

import compiler /

  [ options, modulegraphs, lineinfos, passes, ast, astalgo ]

type
  DustContext = ref object of PPassContext
    mainIndex: FileIndex

var interesting: string
var winner = false

proc massageMessage(s: string): string =
  result = s.splitLines()[0]

proc bolo*(msg: string) =
  ## tell dust which error to "be on look out" for
  interesting = massageMessage(msg)

proc opener(graph: ModuleGraph; module: PSym): PPassContext {.nosinks.} =
  ## the opener learns when we're compiling the test file
  result = DustContext(mainIndex: graph.config.projectMainIdx)

  proc uhoh(config: ConfigRef; info: TLineInfo; msg: string; level: Severity) {.closure, gcsafe.} =
    if massageMessage(msg) == interesting:
      winner = true

  graph.config.structuredErrorHook = uhoh

proc closer(graph: ModuleGraph; context: PPassContext; n: PNode): PNode =
  ## the closer resets the winner flag
  winner = false

proc rewriter(context: PPassContext, n: PNode): PNode {.nosinks.} =
  template c: DustContext = DustContext(context)
  result = n
  # if this isn't the main project, we just bail
  if n.info.fileIndex != c.mainIndex or len(n) == 0:
    return

  # manipulate the test program
  delete result.sons, 0, 0

proc inspector(context: PPassContext, n: PNode): PNode {.nosinks.} =
  template c: DustContext = DustContext(context)
  result = n
  # if this isn't the main project, we just bail
  if n.info.fileIndex != c.mainIndex or len(n) == 0:
    return

  # dump the node if we found the right sort of error
  if winner:
    debug n

const
  dustPass1* = makePass(opener, rewriter, closer)
  dustPass2* = makePass(opener, inspector, closer)
