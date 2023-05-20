package run

import (
	"fmt"
	"text/scanner"

	ab "github.com/pcbuildpluscoding/apibase/std"
	elm "github.com/pcbuildpluscoding/genware/lib/element"
	han "github.com/pcbuildpluscoding/genware/lib/handler"
)

//================================================================//
// PrintProvider
//================================================================//
type PrintProvider struct {
  dd *DataDealer
  cache map[string]Printer
  writer LineWriter
}

//----------------------------------------------------------------//
// Printer
//----------------------------------------------------------------//
func (p *PrintProvider) Print(kind, sectionName string) error {
  switch sectionName {
  case "prefix":
    text := fmt.Sprintf(`  prefix := "%s/"`, p.dd.DbPrefix)
    p.writer.Write(text)
    return nil
  default:
    var err error
    printer, found := p.cache[kind]
    if !found {
      printer, err = p.newPrinter(kind)
      if err != nil {
        return fmt.Errorf("%s printer creation failed : %v", kind, err)
      }
      p.cache[kind] = printer
    }
    printer.SetProperty("SectionName", sectionName)
    err = printer.Print()
    if err != nil {
      logger.Errorf("%s printer errored : %v", kind, err)
    }
    return err
  }
}

//----------------------------------------------------------------//
// newPrinter
//----------------------------------------------------------------//
func (p *PrintProvider) newPrinter(kind string) (Printer, error) {
  switch kind {
  case "Content":
    return NewDVContentPrinter(p.dd, p.writer)
  case "Import":
    return NewDVImportPrinter(p.dd, p.writer)
  default:
    return elm.NewStdPrinter(p.dd, p.writer)
  }
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *PrintProvider) Arrange(spec Runware) error {
  if !spec.HasKeys("Workers") {
    return fmt.Errorf("required taskSpec property Workers is undefined")
  }
  elist := ab.NewErrorlist(true)
  var err error
  for _, kind := range spec.StringList("Workers") {
    logger.Debugf("creating new %s printer", kind)
    p.cache[kind], err = p.newPrinter(kind)
    elist.Add(err)
  }
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *PrintProvider) Start() error {
  elist := ab.NewErrorlist(true)
  for _, printer := range p.cache {
    elist.Add(printer.Start())
  }
  rules := elm.FlowRule{
    "Sync": true,
    "UNCLUSTERED": true,
  }
  elist.Add(p.dd.Start(rules))
  return elist.Unwrap()
}

//================================================================//
// DVComposer
//================================================================//
type LineParser_DVC func(*DVComposer, string) LineParser_DVC
type TokenParser_DVC func(*DVComposer, *ScanData) TokenParser_DVC
type DVComposer struct {
  Component
  lineParser LineParser_DVC
  lineState int
  provider PrintProvider
  skipLineCount *int
  tokenParser TokenParser_DVC
  tokenState int
  writer LineWriter
}

//----------------------------------------------------------------//
// composeL0
//----------------------------------------------------------------//
func (c *DVComposer) composeL0(line string) (LineParser_DVC) {
  switch c.lineState {
  case 1:
    c.provider.Print("Import", "required.imports")
  case 2:
    c.provider.Print("Content", "content")
  case 3:
    c.provider.Print("Prefix", "prefix")
  }
  c.lineState = 0
  return (*DVComposer).composeL0
}

//----------------------------------------------------------------//
// composeT0
//----------------------------------------------------------------//
func (c *DVComposer) composeT0(sd *ScanData) TokenParser_DVC {
  switch c.tokenState {
  case 0:
    if sd.Token == "// compose:import" {
      logger.Debugf("$$$$$$$$$ compose:import tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 1
      c.lineState = 1
    }
  case 1:
    if sd.Token == "// compose:content" {
      logger.Debugf("$$$$$$$$$ compose:content tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 2
      c.lineState = 2
    }
  case 2:
    if sd.Token == "// compose:prefix" {
      logger.Debugf("$$$$$$$$$ compose:prefix tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 0
      c.lineState = 3
      return nil
    }
  }
  return (*DVComposer).composeT0
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (c *DVComposer) EditLine(line *string, lineNum int) {}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (c *DVComposer) EndOfFile(lines ...string) {
  if lines == nil {
    return
  }
  if lines[0] != "\n" && lines[0] != "" {
    c.writer.Write(lines[0])
  }
}

//----------------------------------------------------------------//
// EndOfSection
//----------------------------------------------------------------//
func (DVComposer) EndOfSection(...string) {}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (c *DVComposer) PutLine(line string) {
  if c.lineParser != nil {
    c.lineParser = c.lineParser(c, line)
  }
  if *c.skipLineCount == 0 {
    c.writer.Write(line)
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (c *DVComposer) Run(scanner scanner.Scanner) error {
  err := c.provider.Start()
  if err != nil {
    return err
  }

  c.lineParser = (*DVComposer).composeL0
  c.tokenParser = (*DVComposer).composeT0

  handler := han.NewScanHandler(c, c.skipLineCount)

  return handler.Run(scanner)
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (c *DVComposer) skipLines(skipLineCount int) {
  *c.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// String
//----------------------------------------------------------------//
func (c *DVComposer) String() string {
  return c.Desc
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (c *DVComposer) UseToken(sd *ScanData) {
  if c.tokenParser != nil {
    c.tokenParser = c.tokenParser(c, sd)
  }
}