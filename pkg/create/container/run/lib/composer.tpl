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
  spec Runware
  writer LineWriter
}

//----------------------------------------------------------------//
// Printer
//----------------------------------------------------------------//
func (p *PrintProvider) Print(kind, sectionName string) error {
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
  return printer.Print()
}

//----------------------------------------------------------------//
// newPrinter
//----------------------------------------------------------------//
func (p *PrintProvider) newPrinter(kind string) (Printer, error) {
  switch kind {
  case "VarDec":
    return elm.NewVardecPrinter(p.dd, p.spec, p.writer)
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
    p.cache[kind], err = p.newPrinter(kind)
    elist.Add(err)
  }
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *PrintProvider) Start() error {
  rules := elm.FlowRule{
    "Sync": true,
    "UNCLUSTERED": true,
  }
  return p.dd.Start(rules)
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (p *PrintProvider) String() string {
  return p.dd.String()
}

//================================================================//
// CRComposer
//================================================================//
type LineParser_CRC func(*CRComposer, string) LineParser_CRC
type TokenParser_CRC func(*CRComposer, *ScanData) TokenParser_CRC
type CRComposer struct {
  Component
  lineParser LineParser_CRC
  lineState int
  skipLineCount *int
  tokenParser TokenParser_CRC
  tokenState int
  provider PrintProvider
  writer LineWriter
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (c *CRComposer) EditLine(line *string, lineNum int) {}

//----------------------------------------------------------------//
// composeL0
//----------------------------------------------------------------//
func (c *CRComposer) composeL0(line string) (LineParser_CRC) {
  switch c.lineState {
  case 1:
    c.provider.Print("Default", "import")
  case 2:
    c.provider.Print("VarDec", "createContainer")
  case 3:
    c.provider.Print("VarDec", "processPullCommandFlagsInRun")
  case 4:
    c.provider.Print("VarDec", "generateRootfsOpts")
  case 5:
    c.provider.Print("Default", "withContainerLabels")
  case 6:
    c.provider.Print("VarDec", "readKVStringsMapfFromLabel")
  case 7:
    c.provider.Print("VarDec", "parseKVStringsMapFromLogOpt")
  case 8:
    c.provider.Print("Default", "withStop")
  }
  c.lineState = 0
  return (*CRComposer).composeL0
}

//----------------------------------------------------------------//
// composeT0
//----------------------------------------------------------------//
func (c *CRComposer) composeT0(sd *ScanData) TokenParser_CRC {
  switch c.tokenState {
  case 0:
    if sd.Token == "// compose:import" {
      logger.Debugf("$$$$$$$$$ compose:import tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 1
      c.lineState = 1
    }
  case 1:
    if sd.Token == "// compose:createContainer" {
      logger.Debugf("$$$$$$$$$ compose:createContainer tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 2
      c.lineState = 2
    }
  case 2:
    if sd.Token == "// compose:processPullCommandFlagsInRun" {
      logger.Debugf("$$$$$$$$$ compose:processPullCommandFlagsInRun tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 3
      c.lineState = 3
    }
  case 3:
    if sd.Token == "// compose:generateRootfsOpts" {
      logger.Debugf("$$$$$$$$$ compose:generateRootfsOpts tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 4
      c.lineState = 4
    }
  case 4:
    if sd.Token == "// compose:withContainerLabels" {
      logger.Debugf("$$$$$$$$$ compose:withContainerLabels tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 5
      c.lineState = 5
    }
  case 5:
    if sd.Token == "// compose:readKVStringsMapfFromLabel" {
      logger.Debugf("$$$$$$$$$ compose:readKVStringsMapfFromLabel tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 6
      c.lineState = 6
    } 
  case 6:
    if sd.Token == "// compose:parseKVStringsMapFromLogOpt" {
      logger.Debugf("$$$$$$$$$ compose:parseKVStringsMapFromLogOpt tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 7
      c.lineState = 7
    } 
  case 7:
    if sd.Token == "// compose:withStop" {
      logger.Debugf("$$$$$$$$$ compose:withStop tag detected $$$$$$$$$$")
      c.skipLines(1)
      c.tokenState = 0
      c.lineState = 8
      return nil
    }
  }
  return (*CRComposer).composeT0
}


//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (c *CRComposer) EndOfFile(...string) {
  switch c.lineState {
  case 8:
    // this means the 'compose:withStop' token was detected and lineState
    // set = 9 but the lineParser did not run since EOF happened
    c.provider.Print("default", "withStop")
  }
}

//----------------------------------------------------------------//
// Start
//----------------------------------------------------------------//
func (c *CRComposer) Run(scanner scanner.Scanner) error {
  err := c.provider.Start()
  if err != nil {
    return err
  }

  c.lineParser = (*CRComposer).composeL0
  c.tokenParser = (*CRComposer).composeT0

  handler := han.NewScanHandler(c, c.skipLineCount)

  return handler.Run(scanner)
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (c *CRComposer) PutLine(line string) {
  if c.lineParser != nil {
    c.lineParser = c.lineParser(c, line)
  }
  if *c.skipLineCount == 0 {
    c.writer.Write(line)
  }
}

//----------------------------------------------------------------//
// String
//----------------------------------------------------------------//
func (c *CRComposer) String() string {
  return c.Desc
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (c *CRComposer) skipLines(skipLineCount int) {
  *c.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (c *CRComposer) UseToken(sd *ScanData) {
  if c.tokenParser != nil {
    c.tokenParser = c.tokenParser(c, sd)
  }
}
