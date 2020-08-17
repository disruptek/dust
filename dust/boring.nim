##[

the boring bits that really aren't very relevant to dust.

]##

import std/strutils
import std/times
import std/os
import std/parseopt

import compiler /

  [ idents, nimconf, options, pathutils, modulegraphs, condsyms,
  lineinfos, cmdlinehelper, commands, msgs, modules, ast ]

template excludeAllNotes(config: ConfigRef; n: typed) =
  config.notes.excl n
  when compiles(config.mainPackageNotes):
    config.mainPackageNotes.excl n
  when compiles(config.foreignPackageNotes):
    config.foreignPackageNotes.excl n

proc cmdLine(pass: TCmdLinePass, cmd: string; config: ConfigRef) =
  ## parse the command-line into the config
  var p = initOptParser(cmd)
  var argsCount = 1

  config.commandLine.setLen 0
  config.command = "check"
  config.cmd = cmdCheck

  while true:
    next(p)
    case p.kind
    of cmdEnd:
      break
    of cmdLongOption, cmdShortOption:
      config.commandLine.add " "
      config.commandLine.addCmdPrefix p.kind
      config.commandLine.add p.key.quoteShell
      if p.val.len > 0:
        config.commandLine.add ':'
        config.commandLine.add p.val.quoteShell
      if p.key == " ":
        p.key = "-"
        if processArgument(pass, p, argsCount, config):
          break
      else:
        processSwitch(pass, p, config)
    of cmdArgument:
      config.commandLine.add " "
      config.commandLine.add p.key.quoteShell
      if processArgument(pass, p, argsCount, config):
        break

  if pass == passCmd2:
    if {optRun, optWasNimscript} * config.globalOptions == {} and
        config.arguments.len > 0 and
        config.command.normalize notin ["run", "e"]:
      rawMessage(config, errGenerated, errArgsNeedRunOption)

proc helpOnError(config: ConfigRef) =
  const
    Usage = """
  dust [options] [projectfile]

  Options: Same options that the Nim compiler supports.
  """
  msgWriteln(config, Usage, {msgStdout})
  msgQuit 0

proc reset*(graph: ModuleGraph) =
  ## reset the module graph so it is ready for recompilation
  # we're not dirty if we don't have a fileindex
  if graph.config.projectMainIdx != InvalidFileIdx:
    # mark the program as dirty
    graph.markDirty graph.config.projectMainIdx
    # mark dependencies as dirty
    graph.markClientsDirty graph.config.projectMainIdx
    # reset the error counter
    graph.config.errorCounter = 0

proc compile*(graph: ModuleGraph) =
  ## compile a module graph
  reset graph
  let config = graph.config
  config.lastCmdTime = epochTime()
  if config.libpath notin config.searchPaths:
    config.searchPaths.add config.libpath     # make sure we can import

  config.setErrorMaxHighMaybe                 # for now, we honor errorMax
  defineSymbol(config.symbols, "nimcheck")    # useful for static: reasons

  graph.suggestMode = true                    # needed for dirty flags
  compileProject graph                        # process the graph

proc setup*(cache: IdentCache; config: ConfigRef): bool =
  proc noop(graph: ModuleGraph) = discard
  let prog = NimProg(supportsStdinFile: true,
                     processCmdLine: cmdLine, mainCommand: noop)
  initDefinesProg(prog, config, "dust")
  if paramCount() == 0:
    helpOnError(config)
  else:
    processCmdLineAndProjectPath(prog, config)
    result = loadConfigsAndRunMainCommand(prog, cache, config)

proc loadConfig*(cache: IdentCache; filename: string): ConfigRef =
  ## use the ident cache to load the project config for the given filename
  result = newConfigRef()
  initDefines(result.symbols)

  let cfg = filename & ExtSep & "cfg"
  if fileExists(cfg):
    if not readConfigFile(cfg.AbsoluteFile, cache, result):
      raise newException(ValueError, "couldn't parse " & cfg)

  excludeAllNotes(result, hintConf)
  excludeAllNotes(result, hintLineTooLong)

  incl result.options, optStaticBoundsCheck
  excl result.options, optWarns
  excl result.options, optHints
