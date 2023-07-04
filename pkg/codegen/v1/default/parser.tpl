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

func (m *MatchLog) Matches() bool {
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
  Complete bool
  recent LineCache
  Line string
  matcher MatchLog
}

//----------------------------------------------------------------//
// appendToken
//----------------------------------------------------------------//
func (t *Tokenic) appendToken() {
  sd.TknIndex += 1

  if sd.fmtWidth == 0 {
    t.Line += sd.Token
    return
  }
  
  widthFormat := fmt.Sprintf(widthPattern, '%', sd.fmtWidth, 's')
  t.Line += fmt.Sprintf(widthFormat, sd.Token)
}

//----------------------------------------------------------------//
// completed
//----------------------------------------------------------------//
func (t *Tokenic) completed() {
  t.Complete = true
}

//----------------------------------------------------------------//
// matched
//----------------------------------------------------------------//
func (t *Tokenic) Matches(line string) bool {
  if t.Line == line {
    return t.matcher.Matches()
  }
  return false
}

//----------------------------------------------------------------//
// SetMatcher
//----------------------------------------------------------------//
func (t *Tokenic) SetMatcher(times int) {
  t.matcher.times = times
  t.matcher.touched = 0
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (t *Tokenic) Start(jobSpec Runware, client *StreamClient) error {
  return nil
}

//----------------------------------------------------------------//
// trimLine
//----------------------------------------------------------------//
func (t *Tokenic) trimLine() string {
  return strings.TrimSpace(t.Line)
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
    if !t.Complete {
      err = sx.UseLine()
    }
    t.recent.add(t.Line)
    t.Line = ""
    sd.TknIndex = 0
  default:
    t.appendToken()
  }
  return
}

//----------------------------------------------------------------//
// XLine
//----------------------------------------------------------------//
func (t *Tokenic) XLine() *XString {
  x := XString(t.Line)
  return &x
}

//================================================================//
// VdParser
//================================================================//
type VdParser struct {
  Tokenic
  buffer LineCache
  regex map[string] *regexp.Regexp
  state string
  varDec VarDec
}

//----------------------------------------------------------------//
// addVarDec
//----------------------------------------------------------------//
func (p *VdParser) addVarDec(line string) {
  if p.varDec.CacheIsEmpty() {
    client.AddLine("// variable-declarations")
  }
  p.varDec.Add(line)
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
      p.varDec.Add(p.varDec.GetVarDec())
    }
    p.varDec.Add(p.buffer.flush()...)
    p.varDec.Add(p.Line)
  default:
    logger.Warnf("VdParser - unexpected parser state in flushBuffer : %s", p.state)
  }
  p.state = "Parse"
  p.varDec.ResetIndent()
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
    p.buffer.add(p.Line)
  }
}

//----------------------------------------------------------------//
// parseLine
//----------------------------------------------------------------//
func (p *VdParser) parseLine() {
  switch p.state {
  case "Parse":
    switch {
    case p.regex["IfCmdFlag"].MatchString(p.Line):
      p.state = "IfElseBlock"
      if p.regex["IfCmdLookup"].MatchString(p.Line) {
        p.Line = p.rewriteLine("IfCmdLookup", p.Line)
      } else if p.regex["IfCmdChanged"].MatchString(p.Line) {
        p.Line = p.rewriteLine("IfCmdChanged", p.Line)
      } else if p.regex["IfCmdGetErr"].MatchString(p.Line) {
        p.Line = p.rewriteLine("IfCmdGetErr", p.Line)
        p.state = "IfCmdGetErr"
      }
      p.keep(p.Line)
    default:
      if p.regex["CmdGet"].MatchString(p.Line) {
        p.addVarDec(p.varDec.ParseGetter(p.Line).GetVarSetter())
        client.SkipLines(4)
      }
    }
  default:
    switch p.state {
    case "IfCmdGetErr":
      p.keep(p.varDec.IndentLine("return nil, p.Err()"))
      p.state="IfElseBlock"
      logger.Debugf("$$$$$$ switching from IfCmdGetErr back to IfElseBlock - current indent factor : %d", p.varDec.GetIndentFactor())
    case "IfElseBlock":
      if p.regex["CmdGet"].MatchString(p.Line) {
        p.varDec.ParseGetter(p.Line)
        p.Line = p.varDec.GetVarSetter()
        p.state = "NestedVarDec"
      }
      p.keep(p.Line)
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
      p.varDec.DecIndent()
    } else if p.regex["IfBlock"].MatchString(p.Line) {
      p.varDec.IncIndent()
    }
    if p.varDec.GetIndentFactor() == 1 {
      p.flushBuffer()
    }
  case "IfCmdGetErr":
    logger.Debugf("$$$$$$$ PutLine in IfCmdGetErr state $$$$$$$$$")
  case "Parse":
    client.AddLine(p.Line)
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
    line_ := p.varDec.ParseGetter(line).GetParamSetter()
    client.AddLine(line_)
    return p.varDec.GetParamValue()
  default:
    logger.Errorf("VdParser - unknown pattern after initial IfCmdFlag match : %s", line)
    return line
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *VdParser) Start() error {
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
  }
  p.state = "Parse"
  elist.Add(p.varDec.Start())

  return elist.Unwrap()
}

