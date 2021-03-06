import strutils

proc reverse*[T](xs: openarray[T]): seq[T] =
  result = newSeq[T](xs.len)
  for i, x in xs:
    result[result.len-i-1] = x 

proc simplifyPath*(filename: string, f: string): string =
  let file = strutils.replace(f, "\\", "/")
  let fn = strutils.replace(filename, "./", "")
  var dirs: seq[string] = fn.split("/")
  discard dirs.pop
  let pwd = dirs.join("/")
  if pwd == "":
    result = file
  else:
    result = pwd&"/"&file

when defined(mini):
  import
    strutils
  
  proc parentDirEx*(s: string): string =
    let fslash = s.rfind("/")
    let bslash = s.rfind("\\")
    var dirEnd = fslash-1
    if dirEnd < 0:
      dirEnd = bslash-1
    if dirEnd < 0:
      dirEnd = s.len-1
    if dirEnd < 0:
      return s
    return s[0..dirEnd]
    
  proc escapeEx*(s: string, unquoted = false): string =
    for c in s:
      case c
      of '\L': result.add("\\n")
      of '\b': result.add("\\b")
      of '\f': result.add("\\f")
      of '\t': result.add("\\t")
      of '\v': result.add("\\u000b")
      of '\r': result.add("\\r")
      of '"': result.add("\\\"")
      of '\0'..'\7': result.add("\\u000" & $ord(c))
      of '\14'..'\31': result.add("\\u00" & toHex(ord(c), 2))
      of '\\': result.add("\\\\")
      else: result.add(c)
    if unquoted:
      return result
    return "\"" & result & "\""
    
else:
  import os, json
  
  proc parentDirEx*(s: string): string =
    return s.parentDir
    
  proc escapeEx*(s: string, unquoted = false): string =
    if unquoted:
      return s.escapeJsonUnquoted
    return s.escapeJson
