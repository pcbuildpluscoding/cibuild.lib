package run

import (
	"regexp"

	ab "github.com/pcbuildpluscoding/errorlist"
)

//================================================================//
// VarDecParser
//================================================================//
type VarDecParser struct {
  LineCopier
  buffer []interface{}
  blacklist Blacklist
  regex map[string]*regexp.Regexp
  state string
  varId int
  varDec VarDec
}

//----------------------------------------------------------------//
// AddSectionCount
//----------------------------------------------------------------//
func (p *VarDecParser) addSectionCount() {
  p.dd.Put("vardec-count", p.varId)
  p.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// addVarDec
//----------------------------------------------------------------//
func (p *VarDecParser) addVarDec(line interface{}) {
  if p.varId == 0 {
    p.dd.AddLines("// variable-declarations")
  }
  p.dd.Put("vardec/%02d", line, p.varId)
  p.varId += 1
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *VarDecParser) Arrange(rw Runware) error {
  elist := ab.NewErrorlist(true)
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
  isSlice, err := regexp.Compile(`Slice|Array`)
  p.varDec = VarDec{
    isSlice: isSlice,
    indentFactor: 1,
    indentSize: 2,
  }
  elist.Add(err)
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *VarDecParser) EditLine(line *string) {
  if p.blacklist.Matches(*line) {
    return
  }
  p.editLine(line)
  if p.next != nil {
    p.next.EditLine(line)
  }
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *VarDecParser) editLine(line *string) {
  switch p.state {
  case "Parse":
    switch {
    case p.regex["IfCmdFlag"].MatchString(*line):
      p.state = "IfElseBlock"
      if p.regex["IfCmdLookup"].MatchString(*line) {
        *line = p.rewriteLine("IfCmdLookup", *line)
      } else if p.regex["IfCmdChanged"].MatchString(*line) {
      *line = p.rewriteLine("IfCmdChanged", *line)
      } else if p.regex["IfCmdGetErr"].MatchString(*line) {
        *line = p.rewriteLine("IfCmdGetErr", *line)
        p.state = "IfCmdGetErr"
      }
      p.buffer = append(p.buffer, *line)
    default:
      if p.regex["CmdGet"].MatchString(*line) {
        p.addVarDec(p.varDec.ParseGetter(*line).GetVarSetter())
        p.skipLines(4)
      }
    }
  default:
    switch p.state {
    case "IfCmdGetErr":
      line_ := p.varDec.IndentLine("return nil, p.Err()")
      p.buffer = append(p.buffer, line_)
      p.state="IfElseBlock"
      logger.Debugf("$$$$$$ switching from IfCmdGetErr back to IfElseBlock - current indent factor : %d", p.varDec.GetIndentFactor())
    case "IfElseBlock":
      if p.regex["CmdGet"].MatchString(*line) {
        p.varDec.ParseGetter(*line)
        *line = p.varDec.GetVarSetter()
        p.state = "NestedVarDec"
      }
      p.buffer = append(p.buffer, *line)
    case "NestedVarDec":
    default:
      logger.Warnf("%s unexpected parser state in EditLine : |%s|", p.Desc, p.state)
    }
  }
}

//----------------------------------------------------------------//
// flushBuffer
//----------------------------------------------------------------//
func (p *VarDecParser) flushBuffer(line_ string) {
  switch p.state {
  case "IfElseBlock":
    p.dd.FlushBuffer(p.buffer...)
  case "NestedVarDec":
    if p.varDec.equalToken == "=" {
      // prepend a variable declaration if the original setter relied on a previous vardec
      p.buffer = append([]interface{}{
        p.varDec.GetVarDec()},
        p.buffer...
      )
    }
    p.buffer = append(p.buffer, line_)
    for _, line := range p.buffer {
      p.addVarDec(line)
    }
  default:
    logger.Warnf("unexpected parser state in flushBuffer : %s", p.state)
  }
  p.state = "Parse"
  p.buffer = []interface{}{}
  p.varDec.ResetIndent()
}

//----------------------------------------------------------------//
// Next
//----------------------------------------------------------------//
func (p *VarDecParser) Next() TextParser {
  switch p.state {
  case "Parse":
    return p.next
  default:
    return nil
  }
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (p *VarDecParser) PutLine(line string) {
  if p.blacklist.Excluded {
    logger.Infof("$$$$$$$$ line is excluded : |%s|", line)
    return 
  }
  switch p.state {
  case "IfElseBlock", "NestedVarDec":
    if XString(line).Trim() == "}" {
      p.varDec.DecIndent()
    } else if p.regex["IfBlock"].MatchString(line) {
      p.varDec.IncIndent()
    }
    if p.varDec.GetIndentFactor() == 1 {
      p.flushBuffer(line)
    }
  case "IfCmdGetErr":
    logger.Debugf("$$$$$$$ PutLine in IfCmdGetErr state $$$$$$$$$")
  case "Parse":
    if *p.skipLineCount == 0 {
      p.dd.AddLines(line)
    }
  default:
    logger.Errorf("$$$$$$$$ UNKNOWN STATE : %s $$$$$$$$$$", p.state)
  }
}

//----------------------------------------------------------------//
// rewriteLine
//----------------------------------------------------------------//
func (p *VarDecParser) rewriteLine(key, line string) string {
  switch key {
  case "IfCmdLookup":
    prefix, flagName := XString(line).SplitInTwo(`.Flags().Lookup`)
    prefix.Replace(`cmd`,`cspec`,1)
    return prefix.String() + ".Applied" + flagName.SplitNKeepOne(".",2,0).String() + " {"
  case "IfCmdChanged":
    xline := XString(line)
    if xline.Contains(`Flags().Changed`) {
      prefix, flagName := xline.SplitInTwo(`Flags().Changed`)
      prefix.Replace(`cmd.`,`cspec.`,1)
      return prefix.String() + "Applied" + flagName.String()  
    }
    prefix, flagName := xline.SplitInTwo(`Flag`)
    prefix.Replace(`cmd.`,`cspec.`,1)
    flagName.Replace(`.Changed`,"",1)
    return prefix.String() + "Applied" + flagName.String()
  case "IfCmdGetErr":
    line_ := p.varDec.ParseGetter(line).GetParamSetter()
    p.buffer = append(p.buffer, line_)
    return p.varDec.GetParamValue()
  default:
    logger.Errorf("%s - unknown pattern after initial IfCmdFlag match : %s", p.Desc, line)
    return line
  }
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (p *VarDecParser) skipLines(count int) {
  *p.skipLineCount = count
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (p *VarDecParser) SectionEnd() {
  p.addSectionCount()
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *VarDecParser) SectionStart(sectionName string) {
  p.state = "Parse"
  p.varId = 0
  p.blacklist.SetList(sectionName)
}
