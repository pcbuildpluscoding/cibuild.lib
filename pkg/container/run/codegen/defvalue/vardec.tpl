package codegen

import (
  "fmt"
  "regexp"
  "strings"

  erl "github.com/pcbuildpluscoding/errorlist"
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
  dbPrefix string
  indentFactor int
  indentSize int
  regex map[string] *regexp.Regexp
}

//----------------------------------------------------------------//
// addVar
//----------------------------------------------------------------//
func (d *VarDec) addVar(varName, varType, value string) error {
  indent := d.getIndent()
  switch varType {
  case "String":
    if value != `""` {
      d.cache.add(fmt.Sprintf(`%s"%s": %v,`, indent, varName, value))
    }
  case "Bool":
    if value != "false" {
      d.cache.add(fmt.Sprintf(`%s"%s": %s,`, indent, varName, value))
    }
  default:
    switch {
    case d.regex["SliceType"].MatchString(varType):
      if value == "nil" {
        return nil
      }
      value, err := d.rewriteSliceValue(value)
      if err != nil {
        return err
      }
      d.cache.add(fmt.Sprintf(`%s"%s": %s,`, indent, varName, value))
    case d.regex["NumberType"].MatchString(varType):
      d.cache.add(fmt.Sprintf(`%s"%s": %s,`, indent, varName, value))
    default:
      logger.Debugf("$$$$$$ unhandled vartype, value : %s, %s $$$$$", varType, value)
      d.cache.add(fmt.Sprintf(`%s"%s": %s,`, indent, varName, value))
    }
  }
  return nil
}

//----------------------------------------------------------------//
// flush
//----------------------------------------------------------------//
func (d *VarDec) flush() []string {
  return d.cache.flush()
}

//----------------------------------------------------------------//
// formatDbPrefix
//----------------------------------------------------------------//
func (d VarDec) formatDbPrefix(indentFactor int) string {
  d.indentFactor = indentFactor
  return fmt.Sprintf(`%sdbPrefix := "%s"`, d.getIndent(), d.dbPrefix)
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
// rewriteSliceValue
//----------------------------------------------------------------//
func (d *VarDec) rewriteSliceValue(value string) (string, error) {
  parts := strings.SplitN(value, "{", 2)
  if len(parts) == 1 {
    return "", fmt.Errorf("unexpected slice value format : %s", value)
  }
  if ! strings.Contains(parts[1], "}") {
    return "", fmt.Errorf("unexpected slice value format : %s", value)
  }
  extract := strings.Replace(parts[1], "}", "", 1)
  return fmt.Sprintf("[]interface{}{%s}", extract), nil
}

//----------------------------------------------------------------//
// start
//----------------------------------------------------------------//
func (d *VarDec) start() error {
  elist := erl.NewErrorlist(false)
  if d.regex == nil {
    var err error
    d.regex = map[string]*regexp.Regexp{}
    d.regex["NumberType"], err = regexp.Compile(`Uint|Int|Float`) 
    elist.Add(err)
    d.regex["SliceType"], err = regexp.Compile(`Array|Slice`)
    elist.Add(err)
  }
  return elist.Unwrap()
}