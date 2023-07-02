package create

import (
	"fmt"
	"regexp"
	"strings"
)

//================================================================//
// LineCache
//================================================================//
type LineCache struct {
  this []string
  maxsize int
}

//----------------------------------------------------------------//
// add
//----------------------------------------------------------------//
func (c *LineCache) add(line string) {
  if c.maxsize > 0 {
    if len(c.this) == c.maxsize {
      last := len(c.this) - 1
      c.this = append([]string{line}, c.this[:last]...)
      return
    }
  }
  c.this = append(c.this, line)
}

//----------------------------------------------------------------//
// empty
//----------------------------------------------------------------//
func (c *LineCache) empty() bool {
  return len(c.this) == 0
}

//----------------------------------------------------------------//
// flush
//----------------------------------------------------------------//
func (c *LineCache) flush() []string {
  x := make([]string, len(c.this))
  for i, y := range c.this {
    x[i] = y
  }
  c.this = []string{}
  return x
}

//----------------------------------------------------------------//
// prepend
//----------------------------------------------------------------//
func (c *LineCache) prepend(line string) {
  item := []string{line}
  c.this = append(item, c.this...)
}

//----------------------------------------------------------------//
// flush
//----------------------------------------------------------------//
func (c *LineCache) reversed() []string {
  last := len(c.this)-1
  x := make([]string, len(c.this))
  j := 0
  for i := last; i >= 0; i-- {
    x[j] = c.this[i]
    j += 1
  }
  return x
}

//================================================================//
// VarDec
//================================================================//
type VarDec struct {
  cache LineCache
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
// Add
//----------------------------------------------------------------//
func (d *VarDec) Add(items ...string) {
  for _, item := range items {
    d.cache.add(item)
  }
}

//----------------------------------------------------------------//
// DecIndent
//----------------------------------------------------------------//
func (d *VarDec) DecIndent() {
  d.indentFactor -= 1
}

//----------------------------------------------------------------//
// CacheIsEmpty
//----------------------------------------------------------------//
func (d *VarDec) CacheIsEmpty() bool {
  return d.cache.empty()
}

//----------------------------------------------------------------//
// Flush
//----------------------------------------------------------------//
func (d *VarDec) Flush() []string {
  return d.cache.flush()
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
// Prepend
//----------------------------------------------------------------//
func (d *VarDec) Prepend(item string) {
  d.cache.prepend(item)
}

//----------------------------------------------------------------//
// ResetIndent
//----------------------------------------------------------------//
func (d *VarDec) ResetIndent() {
  d.indentFactor = 1
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