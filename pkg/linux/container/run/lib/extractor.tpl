package run

import (
	"fmt"
	"regexp"
	"strings"

	ab "github.com/pcbuildpluscoding/apibase/std"
	stx "github.com/pcbuildpluscoding/strucex/std"
)

//================================================================//
// TextParser
//================================================================//
type TextParser interface {
  EditLine(*string)
  Arrange(Runware) error
  Next() TextParser
  PutLine(string)
  RemoveNext()
  SectionEnd()
  SectionStart(string)
  SetNext(TextParser)
  String() string
}

//================================================================//
// LineCopier
//================================================================//
type LineCopier struct {
  Desc string
  dd *DataDealer
  next TextParser
  skipLineCount *int
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (c *LineCopier) Arrange(rw Runware) error {
  return nil
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (c *LineCopier) EditLine(line *string) {}

//----------------------------------------------------------------//
// Next()
//----------------------------------------------------------------//
func (c *LineCopier) Next() TextParser {
  return c.next
}

//----------------------------------------------------------------//
// RemoveNext
//----------------------------------------------------------------//
func (c *LineCopier) RemoveNext() {
  if c.next == nil {
    return
  } else if c.next.Next() == nil {
    c.next = nil
  } else {
    c.next.RemoveNext()
    c.next = nil
  }
}

//----------------------------------------------------------------//
// SetNext
//----------------------------------------------------------------//
func (c *LineCopier) SetNext(x TextParser) {
  if c.next != nil {
    c.next.SetNext(x)
    return
  }
  c.next = x
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (c *LineCopier) EndOfFile(...string) {
  c.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (p *LineCopier) PutLine(line string) {
  if *p.skipLineCount == 0 {
    p.dd.PutLine(line)
  }
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (c *LineCopier) SectionEnd() {
  c.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *LineCopier) SectionStart(string) {}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *LineCopier) String() string {
  return p.Desc
}

//================================================================//
// LineParserA
//================================================================//
type LineParserA struct {
  LineCopier
  buffer []interface{}
  regex map[string]*regexp.Regexp
  state string
  varId int
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *LineParserA) Arrange(rw Runware) error {
  elist := ab.NewErrorlist(true)
  var err error
  p.regex = map[string]*regexp.Regexp{}
  p.regex["IfCmdFlagErr"], err = regexp.Compile(`if.+err.+cmd\.Flag.+\{`)
  elist.Add(err)
  p.regex["IfCmdLookup"], err = regexp.Compile(`if.+cmd\.Flag.+Lookup.+Changed`)
  elist.Add(err)
  p.regex["IfCmdChanged"], err = regexp.Compile(`if.+cmd\.Flag.+Changed`)
  elist.Add(err)
  p.regex["CmdFlag"], err = regexp.Compile(`err.+cmd\.Flag`)
  elist.Add(err)
  p.regex["SliceType"], err = regexp.Compile(`Slice|Array`)
  elist.Add(err)
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// Next()
//----------------------------------------------------------------//
func (p *LineParserA) Next() TextParser {
  switch p.state {
  case "Parse":
    return p.next
  default:
    return nil
  }
}

//----------------------------------------------------------------//
// AddSectionCount
//----------------------------------------------------------------//
func (p *LineParserA) addSectionCount() {
  var lines = []interface{}{
    "",
    "  if err := cspec.Err(); err != nil {",
    "    return nil, err",
    "  }",
    "  cspec.ErrReset()",
    "",
  }
  // switch p.dd.SectionName {
  // case "createContainer":
  //   lines[2] = "    return nil, nil, err"
  // case "generateRootfsOpts":
  //   lines[2] = "    return nil, nil, nil, err"
  // }
  p.dd.Put("vardec-errtest", lines)
  p.dd.Put("vardec-count", p.varId)
  p.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// addVarDec
//----------------------------------------------------------------//
func (p *LineParserA) addVarDec(line interface{}) {
  if p.varId == 0 {
    p.dd.PutLine("// variable-declarations")
  }
  p.dd.Put("vardec/%02d", line, p.varId)
  p.varId += 1
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *LineParserA) EditLine(line *string) {
  p.editLine(line)
  if p.next != nil {
    p.next.EditLine(line)
  }
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *LineParserA) editLine(line *string) {
  switch p.state {
  case "IfElseBlock":
    if p.regex["CmdFlag"].MatchString(*line) {
      *line, _ = p.rewriteGetter(*line, false)
      p.state = "NestedVarDec"
    }
    p.buffer = append(p.buffer, *line)
  case "NestedVarDec":
    p.buffer = append(p.buffer, *line)
  case "Parse":
    if p.regex["IfCmdChanged"].MatchString(*line) {
      *line = p.rewriteLine("IfCmdChanged", *line)
      p.buffer = append(p.buffer, *line)
      p.state = "IfElseBlock"
    } else if p.regex["IfCmdFlagErr"].MatchString(*line) {
      *line = p.rewriteLine("IfCmdFlagErr", *line)
    } else if p.regex["CmdFlag"].MatchString(*line) {
      *line,_ = p.rewriteGetter(*line, false)
      p.addVarDec(*line)
      p.skipLines(4)
    }
  default:
    logger.Warnf("%s unexpected parser state in EditLine : |%s|", p.Desc, p.state)
  }
}

//----------------------------------------------------------------//
// flushBuffer
//----------------------------------------------------------------//
func (p *LineParserA) flushBuffer() {
  switch p.state {
  case "IfElseBlock":
    p.dd.AddLines(p.buffer...)
  case "NestedVarDec":
    for _, line := range p.buffer {
      p.addVarDec(line)
    }
  default:
    logger.Warnf("unexpected parser state in flushBuffer : %s", p.state)
  }
  p.state = "Parse"
  p.buffer = []interface{}{}
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (p *LineParserA) PutLine(line string) {
  switch p.state {
  case "IfElseBlock", "NestedVarDec":
    if XString(line).Trim() == "}" {
      p.flushBuffer()
    }
  case "Parse":
    if *p.skipLineCount == 0 {
      p.dd.PutLine(line)
    }
  default:
    logger.Errorf("$$$$$$$$ UNKNOWN STATE : %s $$$$$$$$$$", p.state)
  }
}

//----------------------------------------------------------------//
// rewriteGetter
//----------------------------------------------------------------//
func (p *LineParserA) rewriteGetter(line string, useParameter bool) (string, string) {
  varName, remnant := XString(line).SplitInTwo(", ")
  _, equalToken, remnantA := remnant.SplitInThree(" ")
  varType, flagName := remnantA.SplitNKeepOne("Flags().Get",2,1).SplitInTwo(`("`)
  if flagName.Contains("err != nil") {
    flagName, _ = flagName.SplitInTwo(`")`)
  } else {
    flagName.Replace(`")`, "", 1)
  }
  if p.regex["SliceType"].MatchString(varType.String()) {
    varType.Set("StringList")
    if !varType.Contains("String") {
      varType.Set("List")
    }
  }
  if useParameter {
    return fmt.Sprintf("%s %s p.%s()", varName, equalToken, varType), flagName.String() 
  }
  return fmt.Sprintf("%s %s cspec.%s(\"%s\")", varName, equalToken, varType, flagName), flagName.String()
}

//----------------------------------------------------------------//
// rewriteLine
//----------------------------------------------------------------//
func (p *LineParserA) rewriteLine(key, line string) string {
  switch key {
  case "IfCmdLookup":
    prefix, flagName := XString(line).SplitInTwo(`Flags().Lookup`)
    prefix.Replace(`cmd.`,`cspec.`,1)
    return prefix.String() + "Applied" + flagName.SplitNKeepOne(".",2,0).String() + " {"
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
  case "IfCmdFlagErr":
    var fieldName string
    line, fieldName := p.rewriteGetter(line, true)
    line_ := fmt.Sprintf("  p := cspec.Parameter(\"%s\")", fieldName)
    p.dd.PutLine(line_)
    line = fmt.Sprintf("%s; p.Err() != nil {", line)
    return line
  default:
    logger.Errorf("%s - unknown pattern after initial IfCmdFlag match : %s", p.Desc, line)
    return line
  }
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (p *LineParserA) skipLines(count int) {
  *p.skipLineCount = count
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (p *LineParserA) SectionEnd() {
  p.addSectionCount()
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *LineParserA) SectionStart(string) {
  p.state = "Parse"
  p.varId = 0
}

//================================================================//
// ReplaceTextA
//================================================================//
type ReplaceTextA struct {
  matchText string
  thisText string
  withText string
}

//----------------------------------------------------------------//
// Replace
//----------------------------------------------------------------//
func (r ReplaceTextA) Replace(line *string) {
  if strings.Contains(*line, r.matchText) {
    *line = strings.ReplaceAll(*line, r.thisText, r.withText)
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (r ReplaceTextA) Start() {}

//================================================================//
// ReplaceTextB
//================================================================//
type ReplaceTextB struct {
  ReplaceTextA
  done bool
}

//----------------------------------------------------------------//
// Replace
//----------------------------------------------------------------//
func (r *ReplaceTextB) Replace(line *string) {
  if r.done {
    return
  }
  if strings.Contains(*line, r.matchText) {
    *line = strings.ReplaceAll(*line, r.thisText, r.withText)
    logger.Debugf("$$$$$$ ReplaceTextB line edit : %s", *line)
    r.done = true
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (r *ReplaceTextB) Start() {
  r.done = false
}


//================================================================//
// TextReplacer
//================================================================//
type TextReplacer interface {
  Replace(*string)
  Start()
}

//================================================================//
// LineParserB
//================================================================//
type LineParserB struct {
  LineCopier
  sectionId string
  cache map[string][]TextReplacer
  editors []TextReplacer
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *LineParserB) Arrange(spec Runware) error {
  dbPrefix := spec.String("DbPrefix")
  rw,_ := stx.NewRunware(nil)
  err := p.dd.GetWithKey(dbPrefix + "/LineParserB", rw)
  if err != nil {
    return err
  }
  logger.Debugf("%s got sectional data : %v", p.Desc, rw.AsMap())
  w := rw.StringList("Sections")
  p.cache = make(map[string][]TextReplacer, len(w))
  for _, sectionId := range w {
    x := rw.ParamList(sectionId)
    logger.Debugf("%s got %s sectional parameters %v", p.Desc, sectionId, x)
    y := make([]TextReplacer, len(x))
    for i, p_ := range x {
      params := p_.StringList()
      if len(params) < 4 {
        return fmt.Errorf("LineParserB.Arrange failed : ReplaceText requires two parameters - got : %v", params)
      }
      switch params[0] {
      case "ReplaceTextA":
        y[i] = &ReplaceTextA{matchText: params[1], thisText: params[2], withText: params[3]}
      case "ReplaceTextB":
        z := ReplaceTextA{matchText: params[1], thisText: params[2], withText: params[3]}
        y[i] = &ReplaceTextB{ReplaceTextA: z}
      }
      logger.Debugf("%s got TextReplacer : %v", p.Desc, y[i])
    }
    p.cache[sectionId] = y
  }
  return nil
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *LineParserB) EditLine(line *string) {
  for _, x := range p.editors {
    x.Replace(line)
  }
}

//----------------------------------------------------------------//
// SectionStart
//----------------------------------------------------------------//
func (p *LineParserB) SectionStart(section string) {
  var found bool
  if p.editors, found = p.cache[section]; !found {
    logger.Warnf("############ %s no TextReplacers are setup for %s section ###########", p.Desc, section)
    p.editors = []TextReplacer{}
  }
}

//================================================================//
// Sectional
//================================================================//
type Sectional struct {
  name string
  starting *regexp.Regexp
  ending *regexp.Regexp
  parserKind []string
  printStart bool
  printEnd bool
}

func (s Sectional) SectionStart(line string) bool {
  return s.starting.MatchString(line)
}

func (s Sectional) SectionEnd(line string) bool {
  return s.ending.MatchString(line)
}

//================================================================//
// SectionDealer
//================================================================//
type SectionDealer struct {
  Desc string
  section []Sectional
  skipLineCount *int
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (d *SectionDealer) Arrange(dd *DataDealer,spec Runware) error {
  logger.Debugf("%s is arranging ...", d.Desc)
  dbPrefix := spec.String("DbPrefix")
  rw,_ := stx.NewRunware(nil)
  err := dd.GetWithKey(dbPrefix + "/SectionDealer", rw)
  if err != nil {
    return err
  }
  logger.Debugf("%s got jobspec : %v", d.Desc, rw.AsMap())
  elist := ab.NewErrorlist(true)
  d.section = make([]Sectional, len(rw.StringList("Sections")))
  for i, section := range rw.StringList("Sections") {
    x := Sectional{name: section}
    x.parserKind = rw.StringList(fmt.Sprintf("%d/Workers", i))
    params := rw.ParamList(fmt.Sprintf("%d/Starting", i))
    // logger.Debugf("%s starting pattern : %s", section, pattern)
    if len(params) < 2 {
      return fmt.Errorf("%s bad arrangement - %s starting parameter list length is < required length of 2", d.Desc, section)
    }
    pattern := params[0].String()
    x.starting, err = regexp.Compile(pattern)
    x.printStart = params[1].Bool()
    elist.Add(err)
    params = rw.ParamList(fmt.Sprintf("%d/Ending", i))
    if len(params) < 2 {
      return fmt.Errorf("%s bad arrangement - %s starting parameter list length is < required length of 2", d.Desc, section)
    }
    pattern = params[0].String()
    // logger.Debugf("%s ending pattern : %s", section, pattern)
    x.ending, err = regexp.Compile(pattern)
    x.printEnd = params[1].Bool()
    elist.Add(err)
    d.section[i] = x
    logger.Debugf("%s got Sectional instance : %v", d.Desc, x)
  }
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (d *SectionDealer) SectionEnd(line string) bool {
  found := d.section[0].SectionEnd(line)
  if found {
    logger.Debugf("%s printEnd : %v", d.section[0].name, d.section[0].printEnd)
    if !d.section[0].printEnd {
      *d.skipLineCount = 1
    }
  }
  return found
}

//----------------------------------------------------------------//
// SectionStart
//----------------------------------------------------------------//
func (d *SectionDealer) SectionStart(line string) bool {
  found := d.section[0].SectionStart(line)
  if found {
    logger.Debugf("%s printStart : %v", d.section[0].name, d.section[0].printStart)
    if !d.section[0].printStart {
      *d.skipLineCount = 1
    }
  }
  return found
}

//----------------------------------------------------------------//
// getSectionProps
//----------------------------------------------------------------//
func (d *SectionDealer) getSectionProps() (string, []string) {
  return d.section[0].name, d.section[0].parserKind
}

//----------------------------------------------------------------//
// hasNext
//----------------------------------------------------------------//
func (d *SectionDealer) hasNext() bool {
  return len(d.section) > 0
}

//----------------------------------------------------------------//
// setNext
//----------------------------------------------------------------//
func (d *SectionDealer) setNext() {
  if len(d.section) > 1 {
    d.section = d.section[1:]
  }
}