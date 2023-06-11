package run

import (
  "fmt"
  "regexp"
  "strings"

  stx "github.com/pcbuildpluscoding/strucex/std"
)

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
// TextEditorA
//================================================================//
type TextEditorA struct {
  matchText string
  thisText string
  withText string
}

//----------------------------------------------------------------//
// Replace
//----------------------------------------------------------------//
func (r TextEditorA) Replace(line *string) {
  if strings.Contains(*line, r.matchText) {
    *line = strings.ReplaceAll(*line, r.thisText, r.withText)
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (r TextEditorA) Start() {}

//================================================================//
// TextEditorB
//================================================================//
type TextEditorB struct {
  TextEditorA
  done bool
}

//----------------------------------------------------------------//
// Replace
//----------------------------------------------------------------//
func (r *TextEditorB) Replace(line *string) {
  if r.done {
    return
  }
  if strings.Contains(*line, r.matchText) {
    *line = strings.ReplaceAll(*line, r.thisText, r.withText)
    logger.Debugf("$$$$$$ TextEditorB line edit : %s", *line)
    r.done = true
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (r *TextEditorB) Start() {
  r.done = false
}

//================================================================//
// LineEditor
//================================================================//
type LineEditor struct {
  LineCopier
  cache map[string][]TextEditor
  editors []TextEditor
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *LineEditor) Arrange(spec Runware) error {
  logger.Debugf("%s is arranging ...", p.Desc)
  dbkey := spec.String("LineEditor")
  rw,_ := stx.NewRunware(nil)
  err := p.dd.GetWithKey(dbkey, rw)
  if err != nil {
    return err
  }
  logger.Debugf("%s got sectional data : %v", p.Desc, rw.AsMap())
  w := rw.StringList("Sections")
  p.cache = make(map[string][]TextEditor, len(w))
  for _, sectionName := range w {
    x := rw.ParamList(sectionName)
    logger.Debugf("%s got %s sectional parameters %v", p.Desc, sectionName, x)
    y := make([]TextEditor, len(x))
    for i, p_ := range x {
      params := p_.StringList()
      if len(params) < 4 {
        return fmt.Errorf("LineEditor.Arrange failed : TextEditor requires two parameters - got : %v", params)
      }
      switch params[0] {
      case "TextEditorA":
        y[i] = &TextEditorA{matchText: params[1], thisText: params[2], withText: params[3]}
      case "TextEditorB":
        z := TextEditorA{matchText: params[1], thisText: params[2], withText: params[3]}
        y[i] = &TextEditorB{TextEditorA: z}
      }
      logger.Debugf("%s got TextEditor : %v", p.Desc, y[i])
    }
    p.cache[sectionName] = y
  }
  return nil
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *LineEditor) EditLine(line *string) {
  for _, x := range p.editors {
    x.Replace(line)
  }
}

//----------------------------------------------------------------//
// SectionStart
//----------------------------------------------------------------//
func (p *LineEditor) SectionStart(sectionName string) {
  var found bool
  if p.editors, found = p.cache[sectionName]; !found {
    logger.Warnf("############ %s no TextEditor are setup for %s section ###########", p.Desc, sectionName)
    p.editors = []TextEditor{}
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