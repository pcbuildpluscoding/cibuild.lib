package run

import (
  "fmt"
  "io"

  ert "github.com/pcbuildpluscoding/errorlist"
  elm "github.com/pcbuildpluscoding/genware/lib/element"
  han "github.com/pcbuildpluscoding/genware/lib/handler"
)

//================================================================//
// ParserProvider
//================================================================//
type ParserProvider struct {
  Desc string
  dd *DataDealer
  cache map[string]LineParser
  skipLineCount *int
  spec Runware
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *ParserProvider) Arrange(spec Runware) error {
  if !spec.HasKeys("Workers") {
    return fmt.Errorf("%s - required taskSpec property Workers is undefined", p.Desc)
  }
  elist := ert.NewErrorlist(true)
  for _, kind := range spec.StringList("Workers") {
    parser, err := p.newParser(kind, spec)
    if err != nil {
      return err
    }
    err = parser.Arrange(spec)
    p.cache[kind] = parser
    elist.Add(err)
  }
  p.spec = spec
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// newParser
//----------------------------------------------------------------//
func (p *ParserProvider) newParser(kind string, spec Runware) (LineParser, error) {
  switch kind {
  case "VarDecParser":
    return NewVarDecParser(p.dd, p.skipLineCount, spec)
  case "LineEditor":
    return NewLineEditor(p.dd, p.skipLineCount)
  default:
    logger.Debugf("%s - %s is not a registered parser kind, default assigned instead", p.Desc, kind)
    parser := NewLineCopier(p.dd, p.skipLineCount)
    return &parser, nil
  }
}

//----------------------------------------------------------------//
// getEditor
//----------------------------------------------------------------//
func (p *ParserProvider) getParser(kind string) (LineParser, error) {
  var err error
  parser, found := p.cache[kind]
  if ! found {
    parser, err = p.newParser(kind, p.spec)
    if err != nil {
      return nil, err
    }
    err = parser.Arrange(p.spec)
    if err == nil {
      p.cache[kind] = parser
    }
  }
  return parser, err
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *ParserProvider) Start() error {
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
  provider ParserProvider
  sectionName string
  parser LineParser
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
// Run
//----------------------------------------------------------------//
func (p *CRProducer) Run(reader io.Reader) ApiRecord {
  err := p.provider.Start()
  if err != nil {
    return p.WithErr(err)
  }

  handler := han.NewScanHandler(p, p.provider.skipLineCount)

  err = handler.Run(reader)
  return p.CheckErr(err, 400)
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
  p.parser.SectionEnd()
  p.parser.RemoveNext()
  p.parser = nil
  // set the next Sectional instance for sectionStart searching
  p.dealer.setNext()
  section, _ := p.dealer.getSectionProps()
  logger.Debugf("$$$$$$$$$ SectionEnd - new section : %s $$$$$$$$", section)
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
// UseToken
//----------------------------------------------------------------//
func (p *CRProducer) UseToken(sd *ScanData) {}
