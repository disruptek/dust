import std/os

import compiler / [ idents, options, modulegraphs, passes, lineinfos, sem ]

import dust/boring
import dust/pass

proc dust*(filename: string) =
  var cache = newIdentCache()
  var config = loadConfig(cache, filename)

  if not setup(cache, config):
    echo "crashing due to error during setup"
    quit 1

  var interestingErrorMessage: string

  proc notable(config: ConfigRef; info: TLineInfo; msg: string; level: Severity) =
    ## capture the first error
    interestingErrorMessage = msg
    config.structuredErrorHook = nil

  config.verbosity = 0                  # reduce spam
  config.structuredErrorHook = notable  # hook into errors

  # create a new module graph
  var graph = newModuleGraph(cache, config)
  registerPass graph, semPass       # perform semcheck
  compile graph                     # run the compile

  # if the semcheck passes, we have nothing to do
  if config.errorCounter == 0:
    echo "error: " & filename & " passes the semcheck"
    quit 1

  # tell our compilation pass what to look for
  bolo interestingErrorMessage

  # recreate the graph so we can reorder the passes
  graph = newModuleGraph(cache, config)
  registerPass graph, dustPass1      # first, let dust rewrite
  registerPass graph, semPass        # then perform semcheck
  registerPass graph, dustPass2      # then let dust inspect
  compile graph                      # run the sem sandwich

  quit int(config.errorCounter == 0) # success is failure

when isMainModule:
  if paramCount() > 0:
    dust paramStr(1)
  else:
    dust ""
