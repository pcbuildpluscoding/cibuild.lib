package codegen

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
func (c *LineCache) add(lines ...string) {
  if lines == nil {
    return
  }
  c.this = append(c.this, lines...)
  if c.maxsize > 0 {
    if len(c.this) > c.maxsize {
      diff := len(c.this) - c.maxsize
      c.this = c.this[diff:]
    }
  }
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
// add
//----------------------------------------------------------------//
func (d *VarDec) add(items ...string) {
  if d.cacheIsEmpty() {
    client.AddLine("// variable-declarations")
  }
  d.cache.add(items...)
}

//----------------------------------------------------------------//
// decIndent
//----------------------------------------------------------------//
func (d *VarDec) decIndent() {
  d.indentFactor -= 1
}

//----------------------------------------------------------------//
// cacheIsEmpty
//----------------------------------------------------------------//
func (d *VarDec) cacheIsEmpty() bool {
  return d.cache.empty()
}

//----------------------------------------------------------------//
// flush
//----------------------------------------------------------------//
func (d *VarDec) flush() []string {
  return d.cache.flush()
}

//----------------------------------------------------------------//
// formatLine
//----------------------------------------------------------------//
func (d VarDec) formatLine(line string) string {
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
// getIndentFactor
//----------------------------------------------------------------//
func (d *VarDec) getIndentFactor() int {
  return d.indentFactor
}

//----------------------------------------------------------------//
// getParamSetter
//----------------------------------------------------------------//
func (d *VarDec) getParamSetter() string {
  indent := d.getIndent()
  equalToken := "="
  if d.firstParam {
    equalToken = ":="
    d.firstParam = false
  }
  return fmt.Sprintf("%sp %s rc.Parameter(\"%s\")", indent, equalToken, d.flagName)
}

//----------------------------------------------------------------//
// getParamValue
//----------------------------------------------------------------//
func (d VarDec) getParamValue() string {
  indent := d.getIndent()
  if d.inlineErr {
    return fmt.Sprintf("%s%s %s p.%s(); p.Unwrap() != nil {", indent, d.varName, d.equalToken, d.varType)
  }
  return fmt.Sprintf("%s%s %s p.%s()", indent, d.varName, d.equalToken, d.varType)
}

//----------------------------------------------------------------//
// getVarDec
//----------------------------------------------------------------//
func (d VarDec) getVarDec() string {
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
// getVarSetter
//----------------------------------------------------------------//
func (d VarDec) getVarSetter() string {
  indent := d.getIndent()
  return fmt.Sprintf("%s%s %s rc.%s(\"%s\")", indent, d.varName, d.equalToken, d.varType, d.flagName)
}

//----------------------------------------------------------------//
// indentLine
//----------------------------------------------------------------//
func (d VarDec) indentLine(text string) string {
  d.incIndent()
  indent := d.getIndent()
  d.decIndent()
  return fmt.Sprintf("%s%s", indent, text)
}

//----------------------------------------------------------------//
// incIndent
//----------------------------------------------------------------//
func (d *VarDec) incIndent() {
  d.indentFactor += 1
}

//----------------------------------------------------------------//
// parseGetter
//----------------------------------------------------------------//
func (d *VarDec) parseGetter(line string) *VarDec {
  varText, remnant := XString(line).SplitInTwo(", ")
  _, equalToken, remnantA := remnant.SplitInThree(" ")
  varType, flagName := remnantA.SplitNKeepOne("Flags().Get",2,1).SplitInTwo(`("`)
  inlineErr := flagName.Contains("err")
  flagName, _ = flagName.SplitInTwo(`")`)
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
// prepend
//----------------------------------------------------------------//
func (d *VarDec) prepend(item string) {
  d.cache.prepend(item)
}

//----------------------------------------------------------------//
// resetIndent
//----------------------------------------------------------------//
func (d *VarDec) resetIndent() {
  d.indentFactor = 1
}

//----------------------------------------------------------------//
// start
//----------------------------------------------------------------//
func (d *VarDec) start() error {
  var err error
  if d.isSlice == nil {
    d.isSlice, err = regexp.Compile("Slice|Array")
  }
  d.firstParam = true
  return err
}