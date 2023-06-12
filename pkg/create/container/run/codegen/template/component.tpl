package run

import (
  "fmt"
  "regexp"
  "strings"

  stx "github.com/pcbuildpluscoding/strucex/std"
)

//================================================================//
// LineFilter
//================================================================//
type LineFilter struct {
  matchText string
  skipLineCount *int
  times int
}

//----------------------------------------------------------------//
// Parse
//----------------------------------------------------------------//
func (f *LineFilter) Parse(line *string) {
  if f.times == 0 {
    return
  }
  if strings.Contains(*line, f.matchText) {
    // logger.Debugf("$$$$$$$$$$ LineFilter matches with %s $$$$$$$$$$", f.matchText)
    *f.skipLineCount = 1
    if f.times > 0 {
      f.times -= 1
    }
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (f *LineFilter) Start() {}

//================================================================//
// LineAdder
//================================================================//
type LineAdder struct {
  dd *DataDealer
  matchText string
  inserts []interface{}
  times int
}

//----------------------------------------------------------------//
// Parse
//----------------------------------------------------------------//
func (a *LineAdder) Parse(line *string) {
  if a.times == 0 {
    return
  }
  if strings.Contains(*line, a.matchText) {
    // logger.Debugf("$$$$$$$$$$ LineAdder matches with %s $$$$$$$$$$", a.matchText)
    a.dd.AddLines(a.inserts...)
    if a.times > 0 {
      a.times -= 1
    }
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (a *LineAdder) Start()  {}

//================================================================//
// LineCopier
//================================================================//
type LineCopier struct {
  Desc string
  dd *DataDealer
  next SectionParser
  skipLineCount *int
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (c *LineCopier) Arrange(spec Runware) error {
  return nil
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (c *LineCopier) EndOfFile(...string) {
  c.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// Next()
//----------------------------------------------------------------//
func (c *LineCopier) Next() SectionParser {
  return c.next
}

//----------------------------------------------------------------//
// Parse
//----------------------------------------------------------------//
func (c *LineCopier) Parse(line *string) {}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (c *LineCopier) PutLine(line string) {
  if *c.skipLineCount == 0 {
    c.dd.AddLines(line)
  }
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
// SectionEnd
//----------------------------------------------------------------//
func (c *LineCopier) SectionEnd() {
  c.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// SectionStart
//----------------------------------------------------------------//
func (c *LineCopier) SectionStart(sectionName string) {}

//----------------------------------------------------------------//
// SetNext
//----------------------------------------------------------------//
func (c *LineCopier) SetNext(x SectionParser) {
  if c.next != nil {
    c.next.SetNext(x)
    return
  }
  c.next = x
}

//----------------------------------------------------------------//
// String
//----------------------------------------------------------------//
func (c LineCopier) String() string {
  return c.Desc
}

//================================================================//
// LineJudge
//================================================================//
type LineJudge struct {
  LineCopier
  cache map[string][]LineParser
  parsers []LineParser
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (j *LineJudge) Arrange(spec Runware) error {
  logger.Debugf("%s is arranging ...", j.Desc)
  if !spec.HasKeys("LineJudge") {
    j.cache = map[string][]LineParser{}
    return nil
  }
  dbkey := spec.String("LineJudge")
  rw,_ := stx.NewRunware(nil)
  err := j.dd.GetWithKey(dbkey, rw)
  if err != nil {
    return err
  }
  logger.Debugf("%s got sectional data : %v", j.Desc, rw.AsMap())
  w := rw.StringList("Sections")
  j.cache = make(map[string][]LineParser, len(w))
  for _, sectionName := range w {
    x := rw.ParamList(sectionName)
    logger.Debugf("%s got %s sectional parameter list len : %d", j.Desc, sectionName, len(x))
    y := make([]LineParser, len(x))
    for i, z := range x {
      params := z.ParamList()
      switch params[0].String() {
      case "LineFilter":
        if len(params) < 3 {
          return fmt.Errorf("LineJudge.Arrange failed : LineFilter requires two parameters - got : %v", params)
        }
        y[i] = &LineFilter{
                  matchText: params[1].String(),
                  skipLineCount: j.skipLineCount,
                  times: params[2].Int()}
      case "LineAdder":
        if len(params) < 4 {
          return fmt.Errorf("LineJudge.Arrange failed : LineAdder requires two parameters - got : %v", params)
        }
        objkey := fmt.Sprintf("%d/LineAdder", i)
        inserts := strings.Split(rw.String(objkey), "\n")
        y[i] = &LineAdder{
          dd: j.dd,
          matchText: params[1].String(),
          inserts: toInterfaceList(params[2].Int(), inserts),
          times: params[3].Int()}
      default:
        return fmt.Errorf("Unsupported LineParser type : %s", params[0])
      }
      logger.Debugf("%s got LineParser : %v", j.Desc, y[i])
    }
    j.cache[sectionName] = y
  }
  return nil
}

//----------------------------------------------------------------//
// Parse
//----------------------------------------------------------------//
func (j *LineJudge) Parse(line *string) {
  for _, parser := range j.parsers {
    parser.Parse(line)
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (j *LineJudge) SectionStart(sectionName string) {
  var found bool
  if j.parsers, found = j.cache[sectionName]; !found {
    j.parsers = []LineParser{}
  }
}

//================================================================//
// TextEditor
//================================================================//
type TextEditor struct {
  matchText string
  thisText string
  withText string
  times int
}

//----------------------------------------------------------------//
// Parse
//----------------------------------------------------------------//
func (e *TextEditor) Parse(line *string) {
  if e.times == 0 {
    return
  }
  if strings.Contains(*line, e.matchText) {
    // logger.Debugf("$$$$$$$$$$ TextEditor matches with %s $$$$$$$$$$", e.matchText)
    *line = strings.ReplaceAll(*line, e.thisText, e.withText)
    if e.times > 0 {
      e.times -= 1
    }
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (e TextEditor) Start() {}

//================================================================//
// LineEditor
//================================================================//
type LineEditor struct {
  LineCopier
  cache map[string][]LineParser
  editors []LineParser
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (e *LineEditor) Arrange(spec Runware) error {
  logger.Debugf("%s is arranging ...", e.Desc)
  dbkey := spec.String("LineEditor")
  rw,_ := stx.NewRunware(nil)
  err := e.dd.GetWithKey(dbkey, rw)
  if err != nil {
    return err
  }
  logger.Debugf("%s got sectional data : %v", e.Desc, rw.AsMap())
  w := rw.StringList("Sections")
  e.cache = make(map[string][]LineParser, len(w))
  for _, sectionName := range w {
    x := rw.ParamList(sectionName)
    logger.Debugf("%s got %s sectional parameters %v", e.Desc, sectionName, x)
    y := make([]LineParser, len(x))
    for i, z := range x {
      params := z.ParamList()
      if len(params) < 5 {
        return fmt.Errorf("LineEditor.Arrange failed : LineParser requires two parameters - got : %v", params)
      }
      switch params[0].String() {
      case "TextEditor":
        y[i] = &TextEditor{
                  matchText: params[1].String(),
                  thisText: params[2].String(),
                  withText: params[3].String(),
                  times: params[4].Int()}
      }
      logger.Debugf("%s got LineParser : %v", e.Desc, y[i])
    }
    e.cache[sectionName] = y
  }
  return nil
}

//----------------------------------------------------------------//
// Parse
//----------------------------------------------------------------//
func (e *LineEditor) Parse(line *string) {
  for _, x := range e.editors {
    x.Parse(line)
  }
}

//----------------------------------------------------------------//
// SectionStart
//----------------------------------------------------------------//
func (e *LineEditor) SectionStart(sectionName string) {
  var found bool
  if e.editors, found = e.cache[sectionName]; !found {
    logger.Warnf("############ %s no LineParser are setup for %s section ###########", e.Desc, sectionName)
    e.editors = []LineParser{}
  }
}

//================================================================//
// VarDec
//================================================================//
type VarDec struct {
  varName string
  flagName string
  varType string
  equalToken string
  indentFactor int
  indentSize int
  inlineErr bool
  isSlice *regexp.Regexp
  firstParam bool
}

//----------------------------------------------------------------//
// DecIndent
//----------------------------------------------------------------//
func (d *VarDec) DecIndent() {
  d.indentFactor -= 1
}

//----------------------------------------------------------------//
// FormatLine
//----------------------------------------------------------------//
func (d VarDec) FormatLine(line string) string {
  indent := d.getIndent()
  return fmt.Sprintf("%s%s", indent, line)
}

//----------------------------------------------------------------//
// getIndent
//----------------------------------------------------------------//
func (d VarDec) getIndent() string {
  indentFmt := "%" + fmt.Sprintf("%ds", d.indentFactor * d.indentSize)
  return fmt.Sprintf(indentFmt, " ")
}

//----------------------------------------------------------------//
// GetIndentFactor
//----------------------------------------------------------------//
func (d *VarDec) GetIndentFactor() int {
  return d.indentFactor
}

//----------------------------------------------------------------//
// GetParamSetter
//----------------------------------------------------------------//
func (d *VarDec) GetParamSetter() string {
  indent := d.getIndent()
  equalToken := "="
  if d.firstParam {
    equalToken = ":="
    d.firstParam = false
  }
  return fmt.Sprintf("%sp %s cspec.Parameter(\"%s\")", indent, equalToken, d.flagName)
}

//----------------------------------------------------------------//
// GetParamValue
//----------------------------------------------------------------//
func (d VarDec) GetParamValue() string {
  indent := d.getIndent()
  if d.inlineErr {
    return fmt.Sprintf("%s%s %s p.%s(); p.Err() != nil {", indent, d.varName, d.equalToken, d.varType)
  }
  return fmt.Sprintf("%s%s %s p.%s()", indent, d.varName, d.equalToken, d.varType)
}

//----------------------------------------------------------------//
// GetVarDec
//----------------------------------------------------------------//
func (d VarDec) GetVarDec() string {
  goVarType := strings.ToLower(d.varType)
  switch d.varType {
  case "StringList":
    goVarType = "[]string"
  case "ParamList":
    goVarType = "[]Parameter"
  }
  indent := d.getIndent()
  return fmt.Sprintf("%svar %s %s", indent, d.varName, goVarType)
}

//----------------------------------------------------------------//
// GetVarSetter
//----------------------------------------------------------------//
func (d VarDec) GetVarSetter() string {
  indent := d.getIndent()
  return fmt.Sprintf("%s%s %s cspec.%s(\"%s\")", indent, d.varName, d.equalToken, d.varType, d.flagName)
}

//----------------------------------------------------------------//
// IndentLine
//----------------------------------------------------------------//
func (d VarDec) IndentLine(text string) string {
  d.IncIndent()
  indent := d.getIndent()
  d.DecIndent()
  return fmt.Sprintf("%s%s", indent, text)
}

//----------------------------------------------------------------//
// IncIndent
//----------------------------------------------------------------//
func (d *VarDec) IncIndent() {
  d.indentFactor += 1
}

//----------------------------------------------------------------//
// ParseGetter
//----------------------------------------------------------------//
func (d *VarDec) ParseGetter(line string) *VarDec {
  varText, remnant := XString(line).SplitInTwo(", ")
  _, equalToken, remnantA := remnant.SplitInThree(" ")
  varType, flagName := remnantA.SplitNKeepOne("Flags().Get",2,1).SplitInTwo(`("`)
  inlineErr := flagName.Contains("err != nil")
  if inlineErr {
    flagName, _ = flagName.SplitInTwo(`")`)
  } else {
    flagName.Replace(`")`, "", 1)
  }
  var varName string
  if varText.Contains("if") {
    varName = varText.SplitNKeepOne(" ",2,1).Trim()
  } else {
    varName = varText.Trim()
  }
  d.parseVarType(varType)
  d.varName = varName
  d.flagName = flagName.String()
  d.equalToken = equalToken.String()
  d.inlineErr = inlineErr
  return d
}

//----------------------------------------------------------------//
// ResetIndent
//----------------------------------------------------------------//
func (d *VarDec) ResetIndent() {
  d.indentFactor = 1
}

//----------------------------------------------------------------//
// parseVarType
//----------------------------------------------------------------//
func (d *VarDec) parseVarType(varType XString) {
  d.varType = varType.String()
  if d.isSlice.MatchString(varType.String()) {
    if varType.Contains("String") {
      d.varType = "StringList"
    } else {
      d.varType = "ParamList"
    }
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (d *VarDec) Start() error {
  var err error
  if d.isSlice == nil {
    d.isSlice, err = regexp.Compile("Slice|Array")
  }
  d.firstParam = true
  return err
}