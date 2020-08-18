import std/os

import compiler /

  [ idents, options, modulegraphs, passes, lineinfos, sem, pathutils, ast,
    parser, astalgo ]

import dust/spec
import dust/boring
import dust/pass

template semcheck(body: untyped) {.dirty.} =
  ## perform the complete setup and compilation process
  cache = newIdentCache()
  config = loadConfig(cache, filename)
  graph = newModuleGraph(cache, config)

  # perform boring setup of the config using the cache
  if not setup(cache, config):
    echo "crashing due to error during setup"
    quit 1

  config.verbosity = 0                  # reduce spam
  config.structuredErrorHook = uhoh     # hook into errors

  # create a new module graph
  graph = newModuleGraph(cache, config)
  body
  registerPass graph, semPass           # perform semcheck
  compile graph                         # run the compile

proc dust*(filename: AbsoluteFile) =
  var
    graph: ModuleGraph
    cache: IdentCache
    config: ConfigRef
    interestingErrorMessage: string

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
    remains.add parseString(readFile(filename.string),
                            cache = cache, config = config, line = 0,
                            filename = filename.string)
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
    echo "remaining: ", len(remains)        # remaining permutations
    let node = next(remains)                # the next program version

    semcheck:
      registerPass graph, dustPass          # let dust rewrite program

    # extra errors are a problem
    if config.errorCounter > expected:
      echo "got unexpected errors"
    # if we didn't unhook the errors,
    # it means we didn't find the error we were looking for
    elif config.structuredErrorHook != nil:
      echo "didn't get an interesting error"
    # i guess this node is a viable reproduction
    else:
      echo "=== winner"
      echo $node

when isMainModule:
  if paramCount() > 0:
    dust paramStr(1).AbsoluteFile
  else:
    echo "supply a source file to inspect"
