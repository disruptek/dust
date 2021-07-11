import std/os

import compiler /

  [ idents, options, modulegraphs, passes, lineinfos, sem, pathutils, ast,
    parser, astalgo ]

import dust/spec
import dust/boring
import dust/mutate

template semcheck(body: untyped) {.dirty.} =
  ## perform the complete setup and compilation process
  cache = newIdentCache()
  config = newConfigRef()
  graph = newModuleGraph(cache, config)
  graph.loadConfig(filename)

  # perform boring setup of the config using the cache
  if not setup(cache, config, graph):
    echo "crashing due to error during setup"
    quit 1

  config.verbosity = 0                  # reduce spam
  config.structuredErrorHook = uhoh     # hook into errors

  # create a new module graph
  graph = newModuleGraph(cache, config)
  graph.loadConfig(filename)

  body
  registerPass graph, semPass           # perform semcheck
  compile graph                         # run the compile
  inc counter

proc calculateScore(config: ConfigRef; n: PNode): int =
  when defined(dustFewerLines):
    result = config.linesCompiled
  else:
    result = size(n)

proc dust*(filename: AbsoluteFile) =
  var
    graph: ModuleGraph
    cache: IdentCache
    config: ConfigRef
    interestingErrorMessage: string
    best: PNode
    counter = 0
    score: int
    remains: Remains
    rendered: string

  #interestingErrorMessage = """the macro body cannot be compiled, because the parameter 'j' has a generic type"""

  proc uhoh(config: ConfigRef; info: TLineInfo; msg: string; level: Severity) =
    ## capture the first error
    if level == Severity.Error:
      if info.fileIndex == config.projectMainIdx:
        if interestingErrorMessage == "":
          interestingErrorMessage = massageMessage(msg)
        elif interestingErrorMessage == massageMessage(msg):
          config.structuredErrorHook = nil

  # in the first pass, we add the program to our cache
  semcheck:
    # basically, just taking advantage of cache and config values...
    best = parseString(readFile(filename.string),
                       cache = cache, config = config, line = 0,
                       filename = filename.string)
    score = size(best)
    remains.add best
    assert len(remains) > 0

  # if the semcheck passes, we have nothing to do
  if config.errorCounter == 0:
    echo "error: " & filename.string & " passes the semcheck"
    quit 1

  # otherwise, we have an interesting error message to pursue
  echo "interesting: ", interestingErrorMessage,
       " first of ", config.errorCounter, " errors"

  # make note of the expected number of errors
  let expected = config.errorCounter

  while len(remains) > 0:
    echo rendered
    echo "remaining: ", len(remains), " best: ", score
    let node = pop(remains)

    semcheck:
      try:
        writeFile(filename.string, $node)
      except IndexError:
        echo "cheating to get around rendering bug"
        continue

    # extra errors are a problem
    if config.errorCounter > expected:
      echo "(unexpected errors)"
    # if we didn't unhook the errors,
    # it means we didn't find the error we were looking for
    elif config.structuredErrorHook != nil:
      echo "(uninteresting errors)"
    # i guess this node is a viable reproduction
    else:
      let z = calculateScore(config, node)
      if z < score:
        echo "(new high score)"
        best = node
        score = z
        rendered = $best
      for mutant in mutations(node):
        remains.add mutant

  if not best.isNil:
    debug best
    echo "=== minimal after ", counter, "/", remains.count, " semchecks; scored ", score
    echo best
    writeFile(filename.string, $best)

when isMainModule:
  if paramCount() > 0:
    dust paramStr(paramCount()).AbsoluteFile
  else:
    echo "supply a source file to inspect"
