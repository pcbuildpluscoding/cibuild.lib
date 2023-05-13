package run

import (
	"fmt"
	"regexp"
	"strings"
)

//================================================================//
// DVExtractor - Default Value Extractor
//================================================================//
type LineParser_DVE func(*DVExtractor, string) LineParser_DVE
type TokenParser_DVE func(*DVExtractor, *ScanData) TokenParser_DVE
type DVExtractor struct {
  Component
  dd *DataDealer
  cache Runware
  lineNum int
  lineParser LineParser_DVE
  lineState int
  regex map[string]*regexp.Regexp
  skipLineCount *int
  tokenParser TokenParser_DVE
  tokenState int
}

//----------------------------------------------------------------//
// checkImportRef
//----------------------------------------------------------------//
func (e *DVExtractor) checkImportRef(varKey, varType, defValue string) error {
  e.dd.SetSectionName("import")
  dbkey := "dataset"
  x := map[string]interface{}{}
  err := e.dd.Get(dbkey, &x)
  if err != nil {
    return err
  }
  logger.Debugf("####### - defValue : %s - var type : %s", defValue, varType)
  testValue := XString(defValue)
  if e.regex["SpecialChars"].MatchString(defValue) {
    switch  {
    case e.regex["SliceType"].MatchString(varType):
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
  } else if e.regex["FloatType"].MatchString(defValue) {
    logger.Debugf("$$$$$$$$$$$ %s is a float type $$$$$$$$$$$", defValue)
    value := []interface{}{varType, defValue, false}
    e.dd.SetSectionName("content")
    return e.dd.Put(varKey, value)
  }

  refkey := testValue.SplitNKeepOne(".", 2, 0).String()
  logger.Debugf("########### import package refkey : %s ##########", refkey)
  if ! e.cache.HasKeys("refkey") {
    e.cache.Set("refkey", map[string]interface{}{})
  } 
  if _, found := e.cache.Struct("refkey").Fields[refkey]; found {
    logger.Debugf("!!! refkey %s is already loaded !!!", refkey)
  } else if _, found := x[refkey]; found {
    logger.Debugf("$$$$$$ import/dataset refkey : %v $$$$$$$", e.cache.Struct("refkey").AsMap())
    e.cache.SubNode("refkey").Set(refkey, true)
    e.dd.SetSectionName("required.imports")
    importRef, _ := x[refkey].(string)
    if err := e.dd.UpdateCache("ListValue", "", importRef); err != nil {
      return err
    }
  } else {
    logger.Errorf("!! %s default value import reference was not resolved !!", defValue)
    return fmt.Errorf("!! %s default value import reference was not resolved !!", defValue)
  }
  value := []interface{}{varType, defValue, true}
  e.dd.SetSectionName("content")
  return e.dd.Put(varKey, value)
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (e *DVExtractor) EditLine(line *string, lineNum int) {}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (DVExtractor) EndOfFile(...string) {}

//----------------------------------------------------------------//
// EndOfSection
//----------------------------------------------------------------//
func (e *DVExtractor) EndOfSection(args ...string) {
  e.dd.SetSectionName("required.imports")
  e.dd.FlushCache("ListValue", "")
  logger.Infof("%s - end of container/create token parsing !!!!!!!", e.Desc)
}

//----------------------------------------------------------------//
// getVarParams
//----------------------------------------------------------------//
func (e *DVExtractor) getVarParams(line string) (string, string, string) {
  x := XString(line)
  varType_, data := x.SplitNKeepOne("Flags().",2,1).SplitInTwo("(")
  varType := e.regex["ScanL1"].ReplaceAllString(varType_.String(), "")
  varName_, defValue_, _, _ := data.SplitInFour(",")
  last := len(varType) - 1
  if varType[last] == 'P' {
    varType = string(varType[:last])
    varName_, _, defValue_, _ = data.SplitInFour(",")
  }
  varName := e.regex["ScanL1"].ReplaceAllString(string(varName_), "")
  return varType, varName, defValue_.Trim()
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (e *DVExtractor) PutLine(line string) {
  if e.lineParser != nil {
    e.lineParser = e.lineParser(e, line)
  }
}

//----------------------------------------------------------------//
// scanL0
//----------------------------------------------------------------//
func (e *DVExtractor) scanL0(line string) LineParser_DVE {
  switch e.lineState {
  case 1:
    varType, varName, defValue := e.getVarParams(line)
    logger.Debugf("!!!!!!!!! varType, varName, defValue : %s, %s, %v", varType, varName, defValue)
    if strings.Contains(defValue, ".") {
      if err := e.checkImportRef(varName, varType, defValue); err != nil {
        logger.Error(err)
        return nil
      }
      break
    }
    value := []interface{}{varType, defValue, false}
    e.dd.SetSectionName("content")
    err := e.dd.Put(varName, value)
    if err != nil {
      logger.Errorf("trovian put request failed : %v", err)
      return nil
    }
  }
  e.lineState = 0
  return (*DVExtractor).scanL0
}

//----------------------------------------------------------------//
// scanT0
//----------------------------------------------------------------//
func (e *DVExtractor) scanT0(sd *ScanData) TokenParser_DVE {
  switch e.tokenState {
  case 0:
    if sd.Token == "cmd" {
      e.lineNum = sd.LineNum
      e.tokenState = 1
    }
  case 1:
    if e.lineNum != sd.LineNum {
      e.tokenState = 0
    } else if sd.Token == "Flags" {
      logger.Debugf("$$$$$$$$$$$$ cmd.Flags detected $$$$$$$$$$$$")
      e.tokenState = 0
      e.lineState = 1
    }
  }
  return (*DVExtractor).scanT0
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (e *DVExtractor) Start() error {
  logger.Debugf("$$$$$$$$$$$$$$$$$ %s is starting $$$$$$$$$$$", e.Desc)
  if e.regex == nil {
    e.regex = map[string]*regexp.Regexp{}
    e.regex["ScanL1"], _ = regexp.Compile(`[ "]`)
    e.regex["SpecialChars"], _ = regexp.Compile(`[^A-Za-z0-9\.]`)
    e.regex["FloatType"], _ = regexp.Compile(`[+-]?([0-9]*[.])?[0-9]+`)
    e.regex["SliceType"], _ = regexp.Compile(`Array|Slice`)
  }
  e.lineParser = (*DVExtractor).scanL0
  e.tokenParser = (*DVExtractor).scanT0

  e.dd.SetSectionName("required.imports")
  return e.dd.GrantCache("ListValue", "")
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (e *DVExtractor) UseToken(sd *ScanData) {
  if e.tokenParser != nil {
    e.tokenParser = e.tokenParser(e, sd)
  }
}

//================================================================//
// ImportExtractor - Import declaration Extractor
//================================================================//
type LineParser_IDE func(*ImportExtractor, string) LineParser_IDE
type TokenParser_IDE func(*ImportExtractor, *ScanData) TokenParser_IDE
type ImportExtractor struct {
  Component
  dd *DataDealer
  lineParser LineParser_IDE
  lineState int
  skipLineCount *int
  tokenParser TokenParser_IDE
  tokenState int
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (e *ImportExtractor) EditLine(line *string, lineNum int) {}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (ImportExtractor) EndOfFile(...string) {}

//----------------------------------------------------------------//
// EndOfSection
//----------------------------------------------------------------//
func (e *ImportExtractor) EndOfSection(args ...string) {
  dbkey := "dataset"
  logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND - flushing the cache : %s $$$$$$$$$$$", dbkey)
  e.dd.FlushCache("Struct", dbkey)
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (e *ImportExtractor) PutLine(line string) {
  if e.lineParser != nil {
    e.lineParser = e.lineParser(e, line)
  }
}

//----------------------------------------------------------------//
// scanL0
//----------------------------------------------------------------//
func (e *ImportExtractor) scanL0(line string) LineParser_IDE {
  dbkey := "dataset"
  switch e.lineState {
  case 1:
    xline := XString(line).XTrim()
    switch {
    case xline.HasSuffix(`cobra"`):
      break
    default:
      parts := xline.SplitN(" ", 2)
      switch len(parts) {
      case 1:
        parts := xline.ReplaceAll(`"`,"").SplitN("/",-1)
        last := len(parts)-1
        logger.Debugf("$$$$$$$$$$$ adding import ref : %s, %s $$$$$$$$$$$", parts[last], line)
        e.dd.UpdateCache("Struct", dbkey, map[string]interface{}{
          parts[last]: line})
      case 2:
        logger.Debugf("############# adding import ref alias : %s, %s #########", parts[0], line)
        e.dd.UpdateCache("Struct", dbkey, map[string]interface{}{
          parts[0]: line})
      } 
    }
  }
  e.lineState = 0
  return (*ImportExtractor).scanL0
}

//----------------------------------------------------------------//
// scanT0
//----------------------------------------------------------------//
func (e *ImportExtractor) scanT0(sd *ScanData) TokenParser_IDE {
  switch e.tokenState {
  case 0:
    switch {
    case strings.HasPrefix(sd.Token, `"github.com`):
      e.lineState = 1
    }
  }
  return (*ImportExtractor).scanT0
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (e *ImportExtractor) Start() error {
  e.Component.Start()

  e.lineParser = (*ImportExtractor).scanL0
  e.tokenParser = (*ImportExtractor).scanT0

  return e.dd.GrantCache("Struct","dataset")
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (e *ImportExtractor) UseToken(sd *ScanData) {
  if e.tokenParser != nil {
    e.tokenParser = e.tokenParser(e, sd)
  }
}