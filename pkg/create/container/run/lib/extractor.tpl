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
    p.dd.AddLines(line)
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
// String
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
  blacklist Blacklist
  regex map[string]*regexp.Regexp
  state string
  indentFactor int
  varId int
  varDec VarDec
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *LineParserA) Arrange(rw Runware) error {
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
  p.dd.Put("vardec-count", p.varId)
  p.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// addVarDec
//----------------------------------------------------------------//
func (p *LineParserA) addVarDec(line interface{}) {
  if p.varId == 0 {
    p.dd.AddLines("// variable-declarations")
  }
  p.dd.Put("vardec/%02d", line, p.varId)
  p.varId += 1
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *LineParserA) EditLine(line *string) {
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
func (p *LineParserA) editLine(line *string) {
  switch p.state {
  case "Parse":
    switch {
    case p.regex["IfCmdFlag"].MatchString(*line):
      if p.regex["IfCmdLookup"].MatchString(*line) {
        *line = p.rewriteLine("IfCmdLookup", *line)
      } else if p.regex["IfCmdChanged"].MatchString(*line) {
        *line = p.rewriteLine("IfCmdChanged", *line)
      } else if p.regex["IfCmdGetErr"].MatchString(*line) {
        *line = p.rewriteLine("IfCmdGetErr", *line)
      }
      p.buffer = append(p.buffer, *line)
      p.state = "IfElseBlock"
    default:
      if p.regex["CmdGet"].MatchString(*line) {
        p.addVarDec(p.varDec.ParseGetter(*line).GetVarSetter())
        p.skipLines(4)
      }
    }
  default:
    switch p.state {
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

func (p *LineParserA) joinBuffer() string {
  x := make([]string, len(p.buffer))
  for i, y := range p.buffer {
    x[i] = y.(string)
  }
  return strings.Join(x, "|")
}
//----------------------------------------------------------------//
// flushBuffer
//----------------------------------------------------------------//
func (p *LineParserA) flushBuffer(line_ string) {
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
// PutLine
//----------------------------------------------------------------//
func (p *LineParserA) PutLine(line string) {
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
func (p *LineParserA) rewriteLine(key, line string) string {
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
    p.dd.AddLines(p.varDec.ParseGetter(line).GetParamSetter())
    return p.varDec.GetParamValue()
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
func (p *LineParserA) SectionStart(sectionName string) {
  p.state = "Parse"
  p.varId = 0
  p.blacklist.SetList(sectionName)
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
  logger.Debugf("%s is arranging ...", p.Desc)
  dbkey := spec.SubNode("LineParserB").String("Dbkey")
  if dbkey == "" {
    return fmt.Errorf("%s - required Arrangement.LineParserB.Dbkey parameter is undefined", p.Desc)
  }
  rw,_ := stx.NewRunware(nil)
  err := p.dd.GetWithKey(dbkey, rw)
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
  endTimes int
  parserKind []string
  printStart bool
  printEnd bool
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (s Sectional) SectionEnd(line string) bool {
  if s.ending != nil {
    return s.ending.MatchString(line)
  }
  return false
}

//----------------------------------------------------------------//
// SectionStart
//----------------------------------------------------------------//
func (s Sectional) SectionStart(line string) bool {
  return s.starting.MatchString(line)
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
func (d *SectionDealer) Arrange(dd *DataDealer, spec Runware) error {
  logger.Debugf("%s is arranging ...", d.Desc)
  rw,_ := stx.NewRunware(nil)
  dbkey := spec.SubNode("SectionDealer").String("Dbkey")
  if dbkey == "" {
    return fmt.Errorf("%s - required Arrangement.SectionDealer.Dbkey parameter is undefined", d.Desc)
  }
  err := dd.GetWithKey(dbkey, rw)
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
    if len(params) < 3 {
      return fmt.Errorf("%s bad arrangement - %s starting parameter list length is < required length of 2", d.Desc, section)
    }
    pattern = params[0].String()
    if pattern != "EOF" {
      x.ending, err = regexp.Compile(pattern)
    }
    x.endTimes = params[1].Int()
    if x.endTimes < 1 {
      return fmt.Errorf("%s bad arrangement - %s endTimes parameter must be >= 1", d.Desc, section)
    }
    x.printEnd = params[2].Bool()
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
    if d.section[0].endTimes == 1 {
      logger.Debugf("%s printEnd : %v", d.section[0].name, d.section[0].printEnd)
      if !d.section[0].printEnd {
        *d.skipLineCount = 1
      }
    } else {
      found = false
      d.section[0].endTimes -= 1
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