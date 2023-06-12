package run

import (
  "regexp"

  ert "github.com/pcbuildpluscoding/errorlist"
)

//================================================================//
// VarDecParser
//================================================================//
type VarDecParser struct {
  snip:1/VarDecParser/TypeDec
}

//----------------------------------------------------------------//
// AddSectionCount
//----------------------------------------------------------------//
func (p *VarDecParser) addSectionCount() {
  snip:1/VarDecParser/addSectionCount
}

//----------------------------------------------------------------//
// addVarDec
//----------------------------------------------------------------//
func (p *VarDecParser) addVarDec(line interface{}) {
  snip:1/VarDecParser/addVarDec
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *VarDecParser) Arrange(rw Runware) error {
  snip:1/VarDecParser/Arrange
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *VarDecParser) editLine(line *string) {
  snip:1/VarDecParser/editLine
}

//----------------------------------------------------------------//
// flushBuffer
//----------------------------------------------------------------//
func (p *VarDecParser) flushBuffer(line_ string) {
  snip:1/VarDecParser/flushBuffer
}

//----------------------------------------------------------------//
// Next
//----------------------------------------------------------------//
func (p *VarDecParser) Next() SectionParser {
  snip:1/VarDecParser/Next
}

//----------------------------------------------------------------//
// Parse
//----------------------------------------------------------------//
func (p *VarDecParser) Parse(line *string) {
  snip:1/VarDecParser/Parse
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (p *VarDecParser) PutLine(line string) {
  snip:1/VarDecParser/PutLine
}

//----------------------------------------------------------------//
// rewriteLine
//----------------------------------------------------------------//
func (p *VarDecParser) rewriteLine(key, line string) string {
  snip:1/VarDecParser/rewriteLine
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (p *VarDecParser) skipLines(count int) {
  snip:1/VarDecParser/skipLines
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (p *VarDecParser) SectionEnd() {
  snip:1/VarDecParser/SectionEnd
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *VarDecParser) SectionStart(sectionName string) {
  snip:1/VarDecParser/SectionStart
}
