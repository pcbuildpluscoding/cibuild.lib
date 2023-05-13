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
  cache map[string]TextConsumer
  skipLineCount *int
}

//----------------------------------------------------------------//
// newEditor
//----------------------------------------------------------------//
func (p *TCProvider) newEditor(kind string) (TextConsumer, error) {
  switch kind {
  case "Import":
    return NewImportExtractor(p.dd, p.skipLineCount)
  case "DefaultValue":
    return NewDVExtractor(p.dd, p.skipLineCount)
  default:
    return elm.NewLineCopierA(p.dd, p.skipLineCount)
  }
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *TCProvider) Arrange(spec Runware) error {
  if !spec.HasKeys("TextConsumerKinds") {
    return fmt.Errorf("required taskSpec property TextConsumerKinds is undefined")
  }
  elist := ab.NewErrorlist(true)
  var err error
  for _, kind := range spec.StringList("TextConsumerKinds") {
    p.cache[kind], err = p.newEditor(kind)
    elist.Add(err)
  }
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// getEditor
//----------------------------------------------------------------//
func (p *TCProvider) getEditor(kind string) (TextConsumer, error) {
  var err error
  editor, found := p.cache[kind]
  if ! found {
    editor, err = p.newEditor(kind)
    if err == nil {
      p.cache[kind] = editor
    }
  }
  return editor, err
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (p *TCProvider) skipLines(skipLineCount int) {
  *p.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *TCProvider) Start() error {
  return p.dd.Start()
}

//================================================================//
// DVProducer - Default Value extraction Taskery
//================================================================//
type TokenParser_DVP func(*DVProducer, *ScanData) TokenParser_DVP
type DVProducer struct {
  Component
  dd *DataDealer
  lineNum int
  provider TCProvider
  sectionName string
  tokenParser TokenParser_DVP
  tokenState int
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (p *DVProducer) EditLine(line *string, lineNum int) {}

//----------------------------------------------------------------//
// endOfSection - TODO => handle errors properly
//----------------------------------------------------------------//
func (p *DVProducer) endOfSection() {
  p.Component.EndOfSection()
  p.RemoveNext()
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (p *DVProducer) PutLine(line string) {
  if p.Next() != nil {
    p.Next().PutLine(line)
  }
}

//----------------------------------------------------------------//
// removeDelegate - TODO => handle errors properly
//----------------------------------------------------------------//
func (p *DVProducer) removeDelegate() {
  p.EndOfSection()
  p.RemoveNext()
}

//----------------------------------------------------------------//
// scanT0
//----------------------------------------------------------------//
func (p *DVProducer) scanT0(sd *ScanData) TokenParser_DVP {
  switch p.tokenState {
  case 0:
    if sd.Token == "import" && sd.TokenIndex == 0 {
      logger.Debugf("$$$$$$$$$$$ %s IMPORT FOUND on line : %d $$$$$$$$$$$", p.Desc, sd.LineNum)
      p.startOfSection("import", "Import")
      p.provider.skipLines(1)
      p.tokenState = 1
    }
  case 1:
    if sd.Token == ")" && sd.TokenIndex == 0 {
      logger.Debugf("$$$$$$$$$$$ END OF IMPORT FOUND on line : %d with tokenIndex %d $$$$$$$$$$$", sd.LineNum, sd.TokenIndex)
      p.endOfSection()
      p.tokenState = 0
      return (*DVProducer).scanT1
    }
  }
  return (*DVProducer).scanT0
}

//----------------------------------------------------------------//
// scanT1
//----------------------------------------------------------------//
func (p *DVProducer) scanT1(sd *ScanData) TokenParser_DVP {
  switch p.tokenState {
  case 0:
    if sd.Token == "func" {
      p.tokenState = 1
      p.lineNum = sd.LineNum
    }
  case 1:
    if p.lineNum != sd.LineNum {
      p.tokenState = 0
    } else if sd.Token == "setCreateFlags" {
      logger.Debugf("$$$$$$$$$$$ 'func setCreateFlags' detected with TokenIndex : %d $$$$$$$$$$$$", sd.TokenIndex)
      p.startOfSection("content", "DefaultValue")
      p.tokenState = 2
    }
  case 2:
    if sd.Token == "}" && sd.TokenIndex == 0 {
      logger.Debugf("$$$$$$$$$$$$ FINAL curly brace detected $$$$$$$$$$$$")
      p.tokenState = 3
    }
  case 3:
    if sd.Token == "\n" {
      logger.Debugf("$$$$$$$$$$$$ FINAL EOL char detected $$$$$$$$$$$$")
      p.tokenState = 0
      p.removeDelegate()
      return nil
    }
  }
  return (*DVProducer).scanT1
}


//----------------------------------------------------------------//
// setEditor
//----------------------------------------------------------------//
func (p *DVProducer) setEditor(kind string) error {
  x, err := p.provider.getEditor(kind)
  if err != nil {
    return err
  }
  err = x.Start()
  p.SetNext(x)
  return err
}

//----------------------------------------------------------------//
// startOfSection - TODO => handle errors properly
//----------------------------------------------------------------//
func (p *DVProducer) startOfSection(sectionName string, kinds ...string) {
  logger.Debugf("@@@@@@@@@@@@ %s - section %s start @@@@@@@@@@@@", p.Desc, sectionName)
  p.provider.dd.SetSectionName(sectionName)
  p.sectionName = sectionName
  for _, kind := range kinds {
    logger.Debugf("@@@@@@@@@@@@ %s - setting %s editor in section %s @@@@@@@@@@@@", p.Desc, kind, sectionName)
    err := p.setEditor(kind)
    if err != nil {
      logger.Errorf("%s editor creation failed : %v", kind, err)
      return
    }
  }
}

//----------------------------------------------------------------//
// Run
//----------------------------------------------------------------//
func (p *DVProducer) Run(scanner scanner.Scanner) error {
  p.tokenParser = (*DVProducer).scanT0

  handler := han.NewScanHandler(p, p.provider.skipLineCount)

  return handler.Run(scanner)
}

//----------------------------------------------------------------//
// String
//----------------------------------------------------------------//
func (p *DVProducer) String() string {
  return p.Desc
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (p *DVProducer) UseToken(sd *ScanData) {
  if p.tokenParser != nil {
    p.tokenParser = p.tokenParser(p, sd)
  }
}