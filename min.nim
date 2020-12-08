when not defined(windows):
  {.passL: "-rdynamic".}
import 
  streams, 
  critbits, 
  parseopt, 
  strutils, 
  os, 
  json, 
  sequtils,
  algorithm,
  logging,
  asynchttpserver,
  asyncdispatch,
  dynlib

import 
  packages/nimline/nimline,
  packages/niftylogger,
  core/env,
  core/consts,
  core/parser, 
  core/value, 
  core/scope,
  core/interpreter, 
  core/utils,
  core/niftyjsonlogger
import 
  lib/min_lang, 
  lib/min_stack, 
  lib/min_seq, 
  lib/min_dict, 
  lib/min_num,
  lib/min_str,
  lib/min_logic,
  lib/min_time, 
  lib/min_io,
  lib/min_sys,
  lib/min_fs

when not defined(lite):
  import lib/min_http
  import lib/min_net
  import lib/min_crypto
  import lib/min_math

export 
  parser,
  interpreter,
  utils,
  niftylogger,
  value,
  scope,
  min_lang



#-d:ssl -p:. -d:noOpenSSLHacks --dynlibOverride:ssl- --dynlibOverride:crypto- -d:sslVersion:"(" --passL:-Lpath/to/openssl/lib 
#--passL:-Bstatic --passL:-lssl --passL:-lcrypto --passL:-Bdynamic

const PRELUDE* = "prelude.min".slurp.strip
var customPrelude {.threadvar.} : string
customPrelude = ""

if logging.getHandlers().len == 0:
  newNiftyLogger().addHandler()

proc getExecs(): seq[string] =
  var res = newSeq[string](0)
  let getFiles = proc(dir: string) =
    for c, s in walkDir(dir, true):
      if (c == pcFile or c == pcLinkToFile) and not res.contains(s):
        res.add s
  getFiles(getCurrentDir())
  for dir in "PATH".getEnv.split(PathSep):
    getFiles(dir)
  res.sort(system.cmp)
  return res

proc getCompletions(ed: LineEditor, symbols: seq[string]): seq[string] =
  var words = ed.lineText.split(" ")
  var word: string
  if words.len == 0:
    word = ed.lineText
  else:
    word = words[words.len-1]
  if word.startsWith("’"):
    return symbols.mapIt("’" & $it)
  elif word.startsWith("~"):
    return symbols.mapIt("~" & $it)
  if word.startsWith("@"):
    return symbols.mapIt("@" & $it)
  if word.startsWith("#"):
    return symbols.mapIt("#" & $it)
  if word.startsWith(">"):
    return symbols.mapIt(">" & $it)
  if word.startsWith("*"):
    return symbols.mapIt("*" & $it)
  if word.startsWith("("):
    return symbols.mapIt("(" & $it)
  if word.startsWith("<"):
    return toSeq(MINSYMBOLS.readFile.parseJson.pairs).mapIt("<" & $it[0])
  if word.startsWith("$"):
    return toSeq(envPairs()).mapIt("$" & $it[0])
  if word.startsWith("!"):
    return getExecs().mapIt("!" & $it)
  if word.startsWith("&"):
    return getExecs().mapIt("&" & $it)
  if word.startsWith("\""):
    var f = word[1..^1]
    if f == "":
      f = getCurrentDir().replace("\\", "/")  
      return toSeq(walkDir(f, true)).mapIt("\"$1" % it.path.replace("\\", "/"))
    elif f.dirExists:
      f = f.replace("\\", "/")
      if f[f.len-1] != '/':
        f = f & "/"
      return toSeq(walkDir(f, true)).mapIt("\"$1$2" % [f, it.path.replace("\\", "/")])
    else:
      var dir: string
      if f.contains("/") or dir.contains("\\"):
        dir = f.parentDir
        let file = f.extractFileName
        return toSeq(walkDir(dir, true)).filterIt(it.path.toLowerAscii.startsWith(file.toLowerAscii)).mapIt("\"$1/$2" % [dir, it.path.replace("\\", "/")])
      else:
        dir = getCurrentDir()
        return toSeq(walkDir(dir, true)).filterIt(it.path.toLowerAscii.startsWith(f.toLowerAscii)).mapIt("\"$1" % [it.path.replace("\\", "/")])
  return symbols

proc stdLib*(i: In) =
  if not MINSYMBOLS.fileExists:
    MINSYMBOLS.writeFile("{}")
  if not MINHISTORY.fileExists:
    MINHISTORY.writeFile("")
  if not MINRC.fileExists:
    MINRC.writeFile("")
  i.lang_module
  i.stack_module
  i.seq_module
  i.dict_module
  i.io_module
  i.logic_module
  i.num_module
  i.str_module
  i.sys_module
  i.time_module
  i.fs_module
  when not defined(lite):
    i.crypto_module
    i.net_module
    i.math_module
    i.http_module
  if customPrelude == "":
    i.eval PRELUDE, "<prelude>"
  else:
    try:
      i.eval customPrelude.readFile, customPrelude
    except:
      warn("Unable to process custom prelude code in $1" % customPrelude)
  i.eval MINRC.readFile()

proc stdLibNoFiles*(i: In) = 
  i.lang_module
  i.stack_module
  i.seq_module
  i.dict_module
  i.io_module
  i.logic_module
  i.num_module
  i.str_module
  i.sys_module
  i.time_module
  i.fs_module
  when not defined(lite):
    i.crypto_module
    i.net_module
    i.math_module
    i.http_module

type
  LibProc = proc(i: In) {.nimcall.}

proc dynLib*(i: In) =
  discard MINLIBS.existsOrCreateDir
  for library in walkFiles(MINLIBS & "/*"):
    var modname = library.splitFile.name
    var libfile = library.splitFile.name & library.splitFile.ext
    if modname.len > 3 and modname[0..2] == "lib":
      modname = modname[3..modname.len-1]
    let dll = library.loadLib()
    if dll != nil:
      let modsym = dll.symAddr(modname)
      if modsym != nil:
        let modproc = cast[LibProc](dll.symAddr(modname))
        i.modproc()
        info("[$1] Dynamic module loaded successfully: $2" % [libfile, modname])
      else:
        warn("[$1] Library does not contain symbol $2" % [libfile, modname])
    else:
      warn("Unable to load dynamic library: " & libfile)

proc interpret*(i: In, s: Stream) =
  i.stdLib()
  i.dynLib()
  i.open(s, i.filename)
  discard i.parser.getToken() 
  try:
    i.interpret()
  except:
    discard
  i.close()

proc interpret*(i: In, s: string): MinValue = 
  i.open(newStringStream(s), i.filename)
  discard i.parser.getToken() 
  try:
    result = i.interpret()
  except:
    discard
    i.close()

proc minStream(s: Stream, filename: string) = 
  var i = newMinInterpreter(filename = filename)
  i.pwd = filename.parentDir
  i.interpret(s)

proc minString*(buffer: string) =
  minStream(newStringStream(buffer), "input")

proc minFile*(filename: string) =
  var fn = filename
  if not filename.endsWith(".min"):
    fn &= ".min"
  var fileLines = newSeq[string](0)
  var contents = ""
  try:
    fileLines = fn.readFile().splitLines()
  except:
    fatal("Cannot read from file: " & fn)
    quit(3)
  if fileLines[0].len >= 2 and fileLines[0][0..1] == "#!":
    contents = ";;\n" & fileLines[1..fileLines.len-1].join("\n")
  else:
    contents = fileLines.join("\n")
  minStream(newStringStream(contents), fn)

proc minFile*(file: File, filename="stdin") =
  var stream = newFileStream(filename)
  if stream == nil:
    fatal("Cannot read from file: " & filename)
    quit(3)
  minStream(stream, filename)

proc printResult(i: In, res: MinValue) =
  if res.isNil:
    return
  if i.stack.len > 0:
    let n = $i.stack.len
    if res.isQuotation and res.qVal.len > 1:
      echo " ("
      for item in res.qVal:
        echo  "   " & $item
      echo " ".repeat(n.len) & ")"
    elif res.isDictionary and res.dVal.len > 1:
      echo " {"
      for item in res.dVal.pairs:
        var v = ""
        if item.val.kind == minProcOp:
          v = "<native>"
        else:
          v = $item.val.val
        echo  "   " & v & " :" & $item.key
      if res.objType == "":
        echo " ".repeat(n.len) & "}"
      else:
        echo " ".repeat(n.len) & "  ;" & res.objType
        echo " ".repeat(n.len) & "}"
    else:
      echo " $1" % [$i.stack[i.stack.len - 1]]

proc minRepl*(i: var MinInterpreter, simple = false) =
  i.stdLib()
  i.dynLib()
  var s = newStringStream("")
  i.open(s, "<repl>")
  var line: string
  var ed = initEditor(historyFile = MINHISTORY)
  if simple:
    while true:
      i.push("prompt".newSym)
      let vals = i.expect("string")
      let v = vals[0] 
      let prompt = v.getString()
      stdout.write(prompt)
      stdout.flushFile()
      line = stdin.readLine()
      let r = i.interpret($line)
      if $line != "":
        i.printResult(r)
  else:
    while true:
      let symbols = toSeq(i.scope.symbols.keys)
      ed.completionCallback = proc(ed: LineEditor): seq[string] =
        return ed.getCompletions(symbols)
      # evaluate prompt
      i.push("prompt".newSym)
      let vals = i.expect("string")
      let v = vals[0] 
      let prompt = v.getString()
      line = ed.readLine(prompt)
      let r = i.interpret($line)
      if $line != "":
        i.printResult(r)

proc minRepl*(simple = false) = 
  var i = newMinInterpreter(filename = "<repl>")
  i.minRepl(simple)

proc jsonError(s: string): string =
  let j = newJObject()
  j["error"] = %s
  return j.pretty

proc jsonExecutionResult(i: var MinInterpreter, r: MinValue): string =
  let j = newJObject()
  j["result"] = newJNull()
  if not r.isNil:
    j["result"] = i%r
  j["output"] = JSONLOG
  return j.pretty
  
proc minApiExecHandler*(req: Request): Future[void] {.async, gcsafe.} =
  let j = req.body.parseJson
  var i = newMinInterpreter(filename = "<server>")
  i.stdLib()
  var s = newStringStream("")
  i.open(s, "<server>")
  var r: MinValue
  try:
    r = i.interpret(j["data"].getStr)
  except:
    discard
  let headers = newHttpHeaders([("Content-Type","application/json")])
  var iv = i
  await req.respond(Http200, jsonExecutionResult(iv, r), headers)

proc minServer*(address: string, port: int) = 
  newNiftyJsonLogger().addHandler()
  proc handleHttpRequest(req: Request) {.async.} =
    JSONLOG = newJArray()
    if req.url.path == "/api/execute" and req.reqMethod == HttpPost:
      await minApiExecHandler(req)
    else:
      let headers = newHttpHeaders([("Content-Type","application/json")])
      await req.respond(Http400, jsonError("Bad Request"), headers)
  var server = newAsyncHttpServer()
  asyncCheck server.serve(Port(port), handleHttpRequest, address)
  runForever()
    
when isMainModule:

  var REPL = false
  var SIMPLEREPL = false
  var INSTALL = false
  var UNINSTALL = false
  var SERVER = false
  let ADDRESS = "127.0.0.1"
  var PORT = 5555
  var libfile = ""

  let usage* = """  $1 v$2 - a tiny concatenative shell and programming language
  (c) 2014-2020 Fabio Cevasco
  
  Usage:
    min [options] [filename]

  Arguments:
    filename  A $1 file to interpret (default: STDIN).
  Options:
    -—install:<lib>           Install dynamic library file <lib>
    —-uninstall:<lib>         Uninstall dynamic library file <lib>
    -e, --evaluate            Evaluate a $1 program inline
    -h, —-help                Print this help
    -i, —-interactive         Start $1 shell (with advanced prompt)
    -j, --interactive-simple  Start $1 shell (without advanced prompt)
    -s, --server              Start the min HTTP server
    --port                    Specify the server port (default: 5555)
    -l, --log                 Set log level (debug|info|notice|warn|error|fatal)
                              Default: notice
    -p, --prelude:<file.min>  If specified, it loads <file.min> instead of the default prelude code
    -v, —-version             Print the program version""" % [pkgName, pkgVersion]

  var file, s: string = ""
  var args = newSeq[string](0)
  setLogFilter(lvlNotice)
  
  for kind, key, val in getopt():
    case kind:
      of cmdArgument:
        args.add key
        if file == "":
          file = key 
      of cmdLongOption, cmdShortOption:
        case key:
          of "prelude", "p":
            customPrelude = val
          of "log", "l":
            if file == "":
              var val = val
              setLogLevel(val)
          of "port":
            if file == "":
              PORT = val.parseInt
          of "evaluate", "e":
            if file == "":
              s = val
          of "help", "h":
            if file == "":
              echo usage
              quit(0)
          of "version", "v":
            if file == "":
              echo pkgVersion
              quit(0)
          of "server", "s":
            if file == "":
              SERVER = true
          of "interactive", "i":
            if file == "":
              REPL = true
          of "interactive-simple", "j":
            if file == "":
              SIMPLEREPL = true
          of "install":
            if file == "":
              INSTALL = true
              libfile = val
          of "uninstall":
            if file == "":
              UNINSTALL = true
              libfile = val
          else:
            discard
      else:
        discard
  
  if s != "":
    minString(s)
  elif file != "":
    minFile file
  elif INSTALL:
    if not libfile.fileExists:
      fatal("Dynamic library file not found:" & libfile)
      quit(4)
    try:
      libfile.copyFile(MINLIBS/libfile.extractFilename)
    except:
      fatal("Unable to install library file: " & libfile)
      quit(5)
    notice("Dynamic linbrary installed successfully: " & libfile.extractFilename)
    quit(0)
  elif UNINSTALL:
    if not (MINLIBS/libfile.extractFilename).fileExists:
      fatal("Dynamic library file not found:" & libfile)
      quit(4)
    try:
      removeFile(MINLIBS/libfile.extractFilename)
    except:
      fatal("Unable to uninstall library file: " & libfile)
      quit(6)
    notice("Dynamic linbrary uninstalled successfully: " & libfile.extractFilename)
    quit(0)
  elif SERVER:
    minServer(ADDRESS, PORT)
  elif REPL or SIMPLEREPL:
    minRepl(SIMPLEREPL)
    quit(0)
  else:
    minFile stdin, "stdin"
