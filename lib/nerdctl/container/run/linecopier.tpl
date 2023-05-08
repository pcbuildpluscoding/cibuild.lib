package run

import (
	"strings"
)

//================================================================//
// LineCopierB
//================================================================//
type LineParser_LCB func(*LineCopierB, *string) LineParser_LCB
type LineCopierB struct {
  Component
  dd *DataDealer
  lineParser LineParser_LCB
  lineState int
  skipLineCount *int
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (e *LineCopierB) EditLine(line *string, lineNum int) {
  if e.lineParser != nil {
    e.lineParser = e.lineParser(e, line)
  }
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (e *LineCopierB) EndOfFile(...string) {
  e.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// EndOfSection
//----------------------------------------------------------------//
func (e *LineCopierB) EndOfSection(line ...string) {
  e.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (e *LineCopierB) PutLine(line string) {
  if *e.skipLineCount == 0 && e.dd.SectionName != "" {
    e.dd.PutLine(line)
  }
}

//----------------------------------------------------------------//
// scanL0
//----------------------------------------------------------------//
func (e *LineCopierB) scanL0(line *string) LineParser_LCB {
  switch e.lineState {
  case 1:
    *line = strings.Replace(*line, "cmd *cobra.Command", "cspec *CntrSpec", 1)
    return nil
  }
  return (*LineCopierB).scanL0
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (e *LineCopierB) skipLines(skipLineCount int) {
  *e.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (e *LineCopierB) Start() error {
  e.lineParser = (*LineCopierB).scanL0

  // first line is rewritten
  e.lineState = 1
  return nil
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (e *LineCopierB) UseToken(sd *ScanData) {}

//================================================================//
// LineCopierC
//================================================================//
type LineParser_LCC func(*LineCopierC, *string) LineParser_LCC
type TokenParser_LCC func(*LineCopierC, *ScanData) TokenParser_LCC
type LineCopierC struct {
  Component
  dd *DataDealer
  lineParser LineParser_LCC
  lineState int
  skipLineCount *int
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (e *LineCopierC) EditLine(line *string, lineNum int) {
  if e.lineParser != nil {
    e.lineParser = e.lineParser(e, line)
  }
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (e *LineCopierC) EndOfFile(...string) {}

//----------------------------------------------------------------//
// EndOfSection
//----------------------------------------------------------------//
func (e *LineCopierC) EndOfSection(line ...string) {
  e.dd.AddSectionCount()
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (e *LineCopierC) PutLine(line string) {
  if *e.skipLineCount == 0 && e.dd.SectionName != "" {
    e.dd.PutLine(line)
  }
}

//----------------------------------------------------------------//
// scanL0
//----------------------------------------------------------------//
func (e *LineCopierC) scanL0(line *string) LineParser_LCC {
  switch e.lineState {
  case 1:
    if strings.TrimSpace(*line) == "var (" {
      *line = "  var ensured *imgutil.EnsuredImage"
      e.lineState = 2 // after this line, skip the next 3 lines
    }
  case 2:
    e.skipLines(3)
    return nil
  }
  return (*LineCopierC).scanL0
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (e *LineCopierC) skipLines(skipLineCount int) {
  *e.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (e *LineCopierC) Start() error {
  e.lineParser = (*LineCopierC).scanL0
  e.lineState = 1

  return nil
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (e *LineCopierC) UseToken(sd *ScanData) {}
