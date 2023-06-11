package run

import (
  "regexp"

  ab "github.com/pcbuildpluscoding/errorlist"
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
func (p *VarDecParser) EditLine(line *string) {
  snip:1/VarDecParser/EditLine
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
func (p *VarDecParser) Next() TextParser {
  snip:1/VarDecParser/Next
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
