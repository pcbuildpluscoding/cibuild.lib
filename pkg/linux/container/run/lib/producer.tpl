package run

import (
	"fmt"
	"text/scanner"

	ab "github.com/pcbuildpluscoding/apibase/std"
	elm "github.com/pcbuildpluscoding/genware/lib/element"
	han "github.com/pcbuildpluscoding/genware/lib/handler"
)

//================================================================//
// TCProvider
//================================================================//
type TCProvider struct {
  dd *DataDealer
  cache map[string]TextParser
  skipLineCount *int
}

//----------------------------------------------------------------//
// newParser
//----------------------------------------------------------------//
func (p *TCProvider) newParser(kind string) (TextParser, error) {
  switch kind {
  case "LineParserA":
    return NewLineParserA(p.dd, p.skipLineCount)
  case "LineParserB":
    return NewLineParserB(p.dd, p.skipLineCount)
  default:
    logger.Debugf("$$$$$$$$ %s is not a registered parser kind, default assigned instead", kind)
    parser := NewLineCopier(p.dd, p.skipLineCount)
    return &parser, nil
  }
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *TCProvider) Arrange(spec Runware) error {
  if !spec.HasKeys("Workers") {
    return fmt.Errorf("required taskSpec property Workers is undefined")
  }
  elist := ab.NewErrorlist(true)
  for _, kind := range spec.StringList("Workers") {
    parser, err := p.newParser(kind)
    if err != nil {
      return err
    }
    err = parser.Arrange(spec)
    p.cache[kind] = parser
    elist.Add(err)
  }
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// getEditor
//----------------------------------------------------------------//
func (p *TCProvider) getParser(kind string) (TextParser, error) {
  var err error
  editor, found := p.cache[kind]
  if ! found {
    editor, err = p.newParser(kind)
    if err == nil {
      p.cache[kind] = editor
    }
  }
  return editor, err
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *TCProvider) Start() error {
  rules := elm.FlowRule{
    "Sync": true,
    "UNCLUSTERED": true,
  }
  return p.dd.Start(rules)
}

//================================================================//
// CRProducer - Container Run Content Producer
//================================================================//
type CRProducer struct {
  Component
  dealer SectionDealer
  provider TCProvider
  sectionName string
  parser TextParser
  skipLineCount  *int
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *CRProducer) EditLine(line *string, lineNum int) {
  if p.parser == nil {
    if p.dealer.SectionStart(*line) {
      err := p.SectionStart()
      if err != nil {
        logger.Error(err)
      }
      // at this point the section parser is assigned, so next we call EditLine immediately
    }
  }
  if p.parser != nil {
    p.parser.EditLine(line)
  }
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (p *CRProducer) EndOfFile(line ...string) {
  if p.parser != nil {
    p.parser.SectionEnd()
  }
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (p *CRProducer) PutLine(line string) {
  if p.parser != nil {
    if p.dealer.SectionEnd(line) {
      // dealer.SectionEnd(line) conditionally prints the line by setting skipLineCount
      // according to the Sectional.printEnd specification
      p.parser.PutLine(line)
      p.SectionEnd()
    } else {
      p.parser.PutLine(line)
    }
  }
}

//----------------------------------------------------------------//
// setParser
//----------------------------------------------------------------//
func (p *CRProducer) setParser(sectionName, kind string) error {
  parser, err := p.provider.getParser(kind)
  if p.parser != nil {
    p.parser.SetNext(parser)
  } else {
    p.parser = parser
  }
  parser.SectionStart(sectionName)
  return err
}

//----------------------------------------------------------------//
// SectionEnd
//----------------------------------------------------------------//
func (p *CRProducer) SectionEnd(...string) {
  section, _ := p.dealer.getSectionProps()
  logger.Debugf("$$$$$$$$$ SectionEnd - new section : %s $$$$$$$$", section)
  p.parser.SectionEnd()
  p.parser.RemoveNext()
  p.parser = nil
  // set the next Sectional instance for sectionStart searching
  p.dealer.setNext()
}

//----------------------------------------------------------------//
// SectionStart - TODO => handle errors properly
//----------------------------------------------------------------//
func (p *CRProducer) SectionStart() error {
  sectionName, kinds := p.dealer.getSectionProps()
  if len(kinds) == 0 {
    return fmt.Errorf("%s section parser kindList is empty", sectionName)
  }
  logger.Debugf("%s - section %s start", p.Desc, sectionName)
  p.provider.dd.SetSectionName(sectionName)
  p.sectionName = sectionName
  for _, kind := range kinds {
    logger.Debugf("%s - setting %s editor in section %s", p.Desc, kind, sectionName)
    err := p.setParser(sectionName, kind)
    if err != nil {
      return fmt.Errorf("%s editor creation failed : %v", kind, err)
    }
  }
  return nil
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *CRProducer) Run(scanner scanner.Scanner) error {
  err := p.provider.Start()
  if err != nil {
    return err
  }

  handler := han.NewScanHandler(p, p.provider.skipLineCount)

  return handler.Run(scanner)
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (p *CRProducer) UseToken(sd *ScanData) {}
