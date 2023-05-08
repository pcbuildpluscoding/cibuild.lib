package run

import (
	"fmt"
	"regexp"
	"strings"
)

//================================================================//
// VDExtractor - Variable Declaration Extractor
//================================================================//
type LineParser_VDE func(*VDExtractor, *string) LineParser_VDE
type TokenParser_VDE func(*VDExtractor, *ScanData) TokenParser_VDE
type VDExtractor struct {
  Component
  dd *DataDealer
  lineNum int
  lineParser LineParser_VDE
  lineState [2]int
  regex map[string]*regexp.Regexp
  skipLineCount *int
  tokenParser TokenParser_VDE
  tokenState int
  varId int
}

//----------------------------------------------------------------//
// AddSectionCount
//----------------------------------------------------------------//
func (e *VDExtractor) AddSectionCount() {
  var lines = []interface{}{
    "",
    "  if err := cspec.Err(); err != nil {",
    "    return nil, err",
    "  }",
    "  cspec.ErrReset()",
    "",
  }
  switch e.dd.SectionName {
  case "createContainer":
    lines[2] = "    return nil, nil, err"
  case "generateRootfsOpts":
    lines[2] = "    return nil, nil, nil, err"
  }
  e.dd.Put("vardec-errtest", lines)
  e.dd.Put("vardec-count", e.varId)
  e.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// addVarDec
//----------------------------------------------------------------//
func (e *VDExtractor) addVarDec(line string) {
  if e.varId == 0 {
    e.dd.PutLine("// variable-declarations")
  }
  e.dd.Put("vardec/%02d", "  " + line, e.varId)
  e.varId += 1
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (e *VDExtractor) EditLine(line *string, lineNum int) {
  if e.lineParser != nil {
    e.lineParser = e.lineParser(e, line)
  }
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (VDExtractor) EndOfFile(...string) {}

//----------------------------------------------------------------//
// EndOfSection
//----------------------------------------------------------------//
func (e *VDExtractor) EndOfSection(line ...string) {
  e.AddSectionCount()
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (e *VDExtractor) PutLine(line string) {
  if *e.skipLineCount == 0 && e.dd.SectionName != "" {
    e.dd.PutLine(line)
  }
}

//----------------------------------------------------------------//
// rewriteChanged
//----------------------------------------------------------------//
func (VDExtractor) rewriteChanged(line string) string {
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
}

//----------------------------------------------------------------//
// rewriteGetter
//----------------------------------------------------------------//
func (e *VDExtractor) rewriteGetter(line string) (XString, XString) {
  varName, remnant := XString(line).SplitInTwo(",")
  _, equalToken, remnantA := remnant.XTrim().SplitInThree(" ")
  varType, flagName := remnantA.SplitNKeepOne("Flags().Get",2,1).SplitInTwo(`("`)
  flagName.Replace(`")`,"",1)
  if e.regex["SliceType"].MatchString(varType.String()) {
    varType.Set("StringList")
    if !varType.Contains("String") {
      varType.Set("List")
    }
  }
  return XString(fmt.Sprintf("%s %s cspec.%s(\"%s\")", varName, equalToken, varType, flagName)), flagName
}

//----------------------------------------------------------------//
// rewriteLookup
//----------------------------------------------------------------//
func (e *VDExtractor) rewriteLookup(line string) string {
  prefix, flagName := XString(line).SplitInTwo(`Flags().Lookup`)
  prefix.Replace(`cmd.`,`cspec.`,1)
  return prefix.String() + "Applied" + flagName.SplitNKeepOne(".",2,0).String() + " {"
}

//----------------------------------------------------------------//
// scanL0
//----------------------------------------------------------------//
func (e *VDExtractor) scanL0(line *string) LineParser_VDE {
  switch e.lineState[0] {
  case 1:
    *line = strings.Replace(*line, "cmd *cobra.Command", "cspec *CntrSpec", 1)
  case 2:
    xline, flagName := e.rewriteGetter(*line)
    e.addVarDec(xline.Trim())
    if e.regex["AppliedVar"].MatchString(flagName.String()) {
      e.addVarDec("}")
    }
    e.skipLines(4) // skip the cobra command.Getter text
    if e.lineState[1] == 4 || e.lineState[1] == 3 {
      // need an extra line skip for the closing line with a curly brace 
      e.lineState[1] = 0
      e.skipLines(5)
    }
  case 3:
    *line = e.rewriteChanged(*line)
    if e.regex["IfAppliedVar"].MatchString(*line) {
      e.addVarDec(XString(*line).Trim())
      e.skipLines(1)
      e.lineState[1] = 3
    }
  case 4:
    *line = e.rewriteLookup(*line)
    if e.regex["IfAppliedVar"].MatchString(*line) {
      e.addVarDec(XString(*line).Trim())
      e.skipLines(1)
      e.lineState[1] = 4
    }
  case 5:
    if e.regex["AppliedVar"].MatchString(*line) {
      e.addVarDec(XString(*line).Trim())
      e.skipLines(1)
    }
  }
  e.lineState[0] = 0
  return (*VDExtractor).scanL0
}

//----------------------------------------------------------------//
// scanT0
//----------------------------------------------------------------//
func (e *VDExtractor) scanT0(sd *ScanData) TokenParser_VDE {
  switch e.tokenState {
  case 0:
    if sd.Token == "cmd" {
      e.lineNum = sd.LineNum
      e.tokenState = 1
    } else if sd.Token == "var" && sd.TokenIndex == 1 {
      e.lineState[0] = 5
      e.tokenState = 0
    }
  case 1:
    if e.lineNum != sd.LineNum {
      e.tokenState = 0
    } else if strings.HasPrefix(sd.Token, "Flag") {
      e.tokenState = 2
    }
  case 2:
    if e.lineNum != sd.LineNum {
      e.tokenState = 0
    } else if strings.HasPrefix(sd.Token, "Get") {
      e.tokenState = 0
      e.lineState[0] = 2
    } else if sd.Token == "Changed" {
      e.tokenState = 0
      e.lineState[0] = 3
    } else if sd.Token == "Lookup" {
      e.tokenState = 0
      e.lineState[0] = 4
    }
  }
  return (*VDExtractor).scanT0
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (e *VDExtractor) skipLines(skipLineCount int) {
  *e.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (e *VDExtractor) Start() error {
  logger.Debugf("$$$$$$$$$$$$$$$$$ %s is starting $$$$$$$$$$$", e.Desc)
  if e.regex == nil {
    e.regex = map[string]*regexp.Regexp{}
    e.regex["SliceType"], _ = regexp.Compile(`Array|Slice`)
    e.regex["AppliedVar"], _ = regexp.Compile(`pidfile|pidFile|umask`)
    e.regex["IfAppliedVar"], _ = regexp.Compile(`^(\s*if)(.+)(pidfile|pidFile|umask)`)
  }

  e.lineParser = (*VDExtractor).scanL0
  // first line is rewritten
  e.lineState = [2]int{1,0}
  e.tokenParser = (*VDExtractor).scanT0
  e.tokenState = 0
  e.varId = 0
  return nil
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (e *VDExtractor) UseToken(sd *ScanData) {
  if e.tokenParser != nil {
    e.tokenParser = e.tokenParser(e, sd)
  }
}
