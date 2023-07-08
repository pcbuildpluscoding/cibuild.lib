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
// matches
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
// XLine
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
  importRef map[string]string
  refKeys map[string]bool
  regex map[string] *regexp.Regexp
  sectionName string
  varDec VarDec
}

//----------------------------------------------------------------//
// checkImportRef
//----------------------------------------------------------------//
func (p *VdParser) checkImportRef(varKey, varType, defValue string) error {
  logger.Debugf("####### - defValue : %s - var type : %s", defValue, varType)
  testValue := XString(defValue)
  if p.regex["SpecialChars"].MatchString(defValue) {
    switch  {
    case p.regex["SliceType"].MatchString(varType):
      logger.Debugf("$$$$$$$$$$$ %s is a slice type $$$$$$$$$$$", defValue)
      if testValue.Contains("{") {
        parts := testValue.SplitN("{", -1)
        if len(parts) > 1 {
          testValue = XString(parts[1])
          break
        }
      }
    case varType == "String":
      logger.Debugf("$$$$$$$$$ %s is a string with special chars $$$$$$$$", defValue)
      break
    default:
      logger.Debugf("$$$$$$$$$$$ %s is an unknown special case $$$$$$$$$$$", defValue)
      return fmt.Errorf("!! %s default value import reference was not resolved !!", defValue)
    }
  } else if p.regex["FloatType"].MatchString(defValue) {
    logger.Debugf("$$$$$$$$$$$ %s is a float type $$$$$$$$$$$", defValue)
    return p.varDec.addVar(varKey, varType, defValue)
  }

  refkey := testValue.SplitNKeepOne(".", 2, 0).String()
  logger.Debugf("########### import package refkey : %s ##########", refkey)
  if _, found := p.refKeys[refkey]; found {
    logger.Debugf("!!! refkey %s is already loaded !!!", refkey)
  } else if matchRef, found := p.importRef[refkey]; found {
    logger.Debugf("$$$$$$ import/dataset refkey : %v $$$$$$$", p.refKeys)
    p.refKeys[refkey] = true
    client.AddLine(matchRef)
  } else {
    return fmt.Errorf("!! %s default value import reference was not resolved !!", defValue)
  }
  return p.varDec.addVar(varKey, varType, defValue)
}

//----------------------------------------------------------------//
// getVarParams
//----------------------------------------------------------------//
func (p *VdParser) getVarParams() (string, string, string) {
  varType_, data := p.xline().SplitNKeepOne("Flags().",2,1).SplitInTwo("(")
  varType := p.regex["ScanL1"].ReplaceAllString(varType_.String(), "")
  varName_, defValue_, _, _ := data.SplitInFour(",")
  last := len(varType) - 1
  if varType[last] == 'P' {
    varType = string(varType[:last])
    varName_, _, defValue_, _ = data.SplitInFour(",")
  }
  varName := p.regex["ScanL1"].ReplaceAllString(string(varName_), "")
  return varType, varName, defValue_.Trim()
}

//----------------------------------------------------------------//
// parseLine
//----------------------------------------------------------------//
func (p *VdParser) parseLine() {
  switch p.sectionName {
  case "Import":
    xline := p.xline().XTrim()
    parts := xline.SplitN(" ", 2)
    switch len(parts) {
    case 1:
      parts := xline.ReplaceAll(`"`,"").SplitN("/",-1)
      last := len(parts)-1
      logger.Debugf("$$$$$$$$$$$ adding import ref : %s, %s $$$$$$$$$$$", parts[last], p.line)
      refkey := parts[last]
      p.importRef[refkey] = p.line
    case 2:
      logger.Debugf("############# adding import ref alias : %s, %s #########", parts[0], p.line)
      refkey := parts[0]
      p.importRef[refkey] = p.line
    }
  case "VarDec":
    varType, varName, defValue := p.getVarParams()
    logger.Debugf("varType, varName, defValue : %s, %s, %v", varType, varName, defValue)
    if strings.Contains(defValue, ".") {
      if err := p.checkImportRef(varName, varType, defValue); err != nil {
        logger.Error(err)
      }
    } else {
      p.varDec.addVar(varName, varType, defValue)
    }
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
    p.regex["FloatType"], err = regexp.Compile(`[+-]?([0-9]*[.])?[0-9]+`)
    elist.Add(err)
    p.regex["ScanL1"], err = regexp.Compile(`[ "]`)
    elist.Add(err)
    p.regex["SliceType"], err = regexp.Compile(`Array|Slice`)
    elist.Add(err)
    p.regex["SpecialChars"], err = regexp.Compile(`[^A-Za-z0-9\.]`)
    elist.Add(err)
  }
  p.importRef = map[string]string{}
  p.refKeys = map[string]bool{}
  elist.Add(p.varDec.start())
  return elist.Unwrap()
}

