package codegen

import (
  "fmt"
  "regexp"
  "strings"

  erl "github.com/pcbuildpluscoding/errorlist"
)

//================================================================//
// MatchLog
//================================================================//
type MatchLog struct {
  times int
  touched int
}

func (m *MatchLog) matches() bool {
  if m.times == 0 {
    return true
  }
  m.touched += 1
  found := m.times == m.touched
  if found {
    m.touched = 0
  }
  return found
}

//================================================================//
// Tokenic
//================================================================//
type Tokenic struct {
  complete bool
  recent LineCache
  line string
  matcher MatchLog
}

//----------------------------------------------------------------//
// appendToken
//----------------------------------------------------------------//
func (t *Tokenic) appendToken() {
  sd.TknIndex += 1

  if sd.fmtWidth == 0 {
    t.line += sd.Token
    return
  }
  
  widthFormat := fmt.Sprintf(widthPattern, '%', sd.fmtWidth, 's')
  t.line += fmt.Sprintf(widthFormat, sd.Token)
}

//----------------------------------------------------------------//
// completed
//----------------------------------------------------------------//
func (t *Tokenic) completed() {
  t.complete = true
}

//----------------------------------------------------------------//
// matched
//----------------------------------------------------------------//
func (t *Tokenic) matches(line string) bool {
  if t.line == line {
    return t.matcher.matches()
  }
  return false
}

//----------------------------------------------------------------//
// setMatcher
//----------------------------------------------------------------//
func (t *Tokenic) setMatcher(times int) {
  t.matcher.times = times
  t.matcher.touched = 0
}

//----------------------------------------------------------------//
// start
//----------------------------------------------------------------//
func (t *Tokenic) start(jobSpec Runware, client *StreamClient) error {
  return nil
}

//----------------------------------------------------------------//
// trimLine
//----------------------------------------------------------------//
func (t *Tokenic) trimLine() string {
  return strings.TrimSpace(t.line)
}

//----------------------------------------------------------------//
// useToken
//----------------------------------------------------------------//
func (t *Tokenic) useToken() (err error) {
  switch {
  case sd.trune == '\t':
    sd.Token = "  "
    t.appendToken()
  case sd.trune == '\n':
    if !t.complete {
      err = sx.UseLine()
    }
    t.recent.add(t.line)
    t.line = ""
    sd.TknIndex = 0
  default:
    t.appendToken()
  }
  return
}

//----------------------------------------------------------------//
// xline
//----------------------------------------------------------------//
func (t *Tokenic) xline() *XString {
  x := XString(t.line)
  return &x
}

//================================================================//
// VdParser
//================================================================//
type VdParser struct {
  Tokenic
  buffer LineCache
  regex map[string] *regexp.Regexp
  retval map[string] string
  state string
  varDec VarDec
}

//----------------------------------------------------------------//
// addVarDec
//----------------------------------------------------------------//
func (p *VdParser) addVarDec(line string) {
  if p.varDec.cacheIsEmpty() {
    client.AddLine("// variable-declarations")
  }
  p.varDec.add(line)
}

//----------------------------------------------------------------//
// flushBuffer
//----------------------------------------------------------------//
func (p *VdParser) flushBuffer() {
  switch p.state {
  case "IfElseBlock":
    client.AddLine(p.buffer.flush()...)
  case "NestedVarDec":
    if p.varDec.equalToken == "=" {
      p.varDec.add(p.varDec.getVarDec())
    }
    p.varDec.add(p.buffer.flush()...)
    p.varDec.add(p.line)
  default:
    logger.Warnf("VdParser - unexpected parser state in flushBuffer : %s", p.state)
  }
  p.state = "Parse"
  p.varDec.resetIndent()
}

//----------------------------------------------------------------//
// keep
//----------------------------------------------------------------//
func (p *VdParser) keep(lines ...string) {
  if lines != nil {
    for _, line := range lines {
      p.buffer.add(line)
    }
  } else {
    p.buffer.add(p.line)
  }
}

//----------------------------------------------------------------//
// parseLine
//----------------------------------------------------------------//
func (p *VdParser) parseLine(sectionName string) {
  switch p.state {
  case "Parse":
    switch {
    case p.regex["IfCmdFlag"].MatchString(p.line):
      p.state = "IfElseBlock"
      if p.regex["IfCmdLookup"].MatchString(p.line) {
        p.line = p.rewriteLine("IfCmdLookup", p.line)
      } else if p.regex["IfCmdChanged"].MatchString(p.line) {
        p.line = p.rewriteLine("IfCmdChanged", p.line)
      } else if p.regex["IfCmdGetErr"].MatchString(p.line) {
        p.line = p.rewriteLine("IfCmdGetErr", p.line)
        p.state = "IfCmdGetErr"
      }
      p.keep(p.line)
    case p.regex["Return"].MatchString(p.line):
      p.line = p.varDec.formatLine("return opt, nil")
    default:
      if p.regex["CmdGet"].MatchString(p.line) {
        p.addVarDec(p.varDec.parseGetter(p.line).getVarSetter())
        client.SkipLines(4)
      }
    }
  default:
    switch p.state {
    case "IfCmdGetErr":
      line_, _ := p.retval[sectionName]
      p.keep(p.varDec.indentLine(line_))
      p.state="IfElseBlock"
    case "IfElseBlock":
      if p.regex["CmdGet"].MatchString(p.line) {
        p.varDec.parseGetter(p.line)
        p.line = p.varDec.getVarSetter()
        p.state = "NestedVarDec"
      }
      p.keep(p.line)
    case "NestedVarDec":
    default:
      logger.Warnf("VdParser - unexpected parser state in parseLine : |%s|", p.state)
    }
  }
}

//----------------------------------------------------------------//
// putLine
//----------------------------------------------------------------//
func (p *VdParser) putLine() {
  switch p.state {
  case "IfElseBlock","NestedVarDec":
    if p.trimLine() == "}" {
      p.varDec.decIndent()
    } else if p.regex["IfBlock"].MatchString(p.line) {
      p.varDec.incIndent()
    }
    if p.varDec.getIndentFactor() == 1 {
      p.flushBuffer()
    }
  case "IfCmdGetErr":
    logger.Debugf("$$$$$$$ PutLine in IfCmdGetErr state $$$$$$$$$")
  case "Parse":
    client.AddLine(p.line)
  default:
    logger.Errorf("$$$$$$$$ UNKNOWN STATE : %s $$$$$$$$$$", p.state)
  }
}

//----------------------------------------------------------------//
// rewriteLine
//----------------------------------------------------------------//
func (p *VdParser) rewriteLine(key, line string) string {
  switch key {
  case "IfCmdLookup":
    prefix, flagName := XString(line).SplitInTwo(`.Flags().Lookup`)
    prefix.Replace(`cmd`,`rc`,1)
    return prefix.String() + ".Applied" + flagName.SplitNKeepOne(".",2,0).String() + " {"
  case "IfCmdChanged":
    xline := XString(line)
    if xline.Contains(`Flags().Changed`) {
      prefix, flagName := xline.SplitInTwo(`Flags().Changed`)
      prefix.Replace(`cmd.`,`rc.`,1)
      return prefix.String() + "Applied" + flagName.String()  
    }
    prefix, flagName := xline.SplitInTwo(`Flag`)
    prefix.Replace(`cmd.`,`rc.`,1)
    flagName.Replace(`.Changed`,"",1)
    return prefix.String() + "Applied" + flagName.String()
  case "IfCmdGetErr":
    line_ := p.varDec.parseGetter(line).getParamSetter()
    client.AddLine(line_)
    return p.varDec.getParamValue()
  default:
    logger.Errorf("VdParser - unknown pattern after initial IfCmdFlag match : %s", line)
    return line
  }
}

//----------------------------------------------------------------//
// start
//----------------------------------------------------------------//
func (p *VdParser) start() error {
  elist := erl.NewErrorlist(false)
  if p.regex == nil {
    var err error
    p.regex = map[string]*regexp.Regexp{}
    p.regex["IfCmdGetErr"], err = regexp.Compile(`if.+err.+cmd\.Flags\(\).Get.+\{`)
    elist.Add(err)
    p.regex["IfCmdLookup"], err = regexp.Compile(`if.+cmd\.Flag.+Lookup.+Changed`)
    elist.Add(err)
    p.regex["IfCmdChanged"], err = regexp.Compile(`if.+cmd\.Flag.+Changed`)
    elist.Add(err)
    p.regex["CmdGet"], err = regexp.Compile(`err.+cmd\.Flags\(\).Get`)
    elist.Add(err)
    p.regex["IfCmdFlag"], err = regexp.Compile(`if.+cmd\.Flag.+\{`)
    elist.Add(err)
    p.regex["IfBlock"], err = regexp.Compile(`if.+\{`)
    elist.Add(err)
    p.regex["Return"], err = regexp.Compile(`return$`)
    elist.Add(err)
  }
  if p.retval == nil {
    p.retval = map[string]string{
      "processImageSignOptions": "return types.ImageSignOptions{}, p.Unwrap()",
      "processImageVerifyOptions": "return types.ImageVerifyOptions{}, p.Unwrap()",
    }
  }
  p.state = "Parse"
  elist.Add(p.varDec.start())

  return elist.Unwrap()
}

