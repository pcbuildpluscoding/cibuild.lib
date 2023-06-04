package run

import (
	"fmt"
	"io"

	ab "github.com/pcbuildpluscoding/apibase/std"
	elm "github.com/pcbuildpluscoding/genware/lib/element"
	han "github.com/pcbuildpluscoding/genware/lib/handler"
)

//================================================================//
// PrintProvider
//================================================================//
type PrintProvider struct {
  Desc string
  dd *DataDealer
  cache map[string]Printer
  spec Runware
  writer LineWriter
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (p *PrintProvider) Arrange(spec Runware) error {
  if !spec.HasKeys("Workers") {
    return fmt.Errorf("%s - required taskSpec property Workers is undefined", p.Desc)
  }
  elist := ab.NewErrorlist(true)
  var err error
  for _, kind := range spec.StringList("Workers") {
    p.cache[kind], err = p.newPrinter(kind, spec)
    elist.Add(err)
  }
  p.spec = spec
  return elist.Unwrap()
}

//----------------------------------------------------------------//
// newPrinter
//----------------------------------------------------------------//
func (p *PrintProvider) newPrinter(kind string, spec Runware) (Printer, error) {
  switch kind {
  case "VarDec":
    vdet, err := NewVarDecErrTest(p.dd, spec)
    if err != nil {
      return nil, err
    }
    return elm.NewVardecPrinterA(p.dd, vdet, p.writer)
  default:
    return elm.NewStdPrinter(p.dd, p.writer)
  }
}

//----------------------------------------------------------------//
// Printer
//----------------------------------------------------------------//
func (p *PrintProvider) Print(kind, sectionName string) error {
  var err error
  printer, found := p.cache[kind]
  if !found {
    printer, err = p.newPrinter(kind, p.spec)
    if err != nil {
      return fmt.Errorf("%s - %s printer creation failed : %v", p.Desc, kind, err)
    }
    p.cache[kind] = printer
  }
  printer.SetProperty("SectionName", sectionName)
  return printer.Print()
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
// Composer
//================================================================//
type Composer struct {
  Component
  dealer SectionDealer
  provider PrintProvider
  sectionName string
  skipLineCount  *int
  writer LineWriter
}

//----------------------------------------------------------------//
// EditLine
//----------------------------------------------------------------//
func (c *Composer) EditLine(line *string, lineNum int) {
  if c.dealer.SectionStart(*line) {
    c.PrintSection()
  }
}

//----------------------------------------------------------------//
// EndOfFile
//----------------------------------------------------------------//
func (c *Composer) EndOfFile(lines ...string) {
  if c.dealer.hasNext() {
    c.PrintSection()
  }
}

//----------------------------------------------------------------//
// PrintSection
//----------------------------------------------------------------//
func (c *Composer) PrintSection() {
  sectionName, kinds := c.dealer.getSectionProps()
  if len(kinds) == 0 {
    logger.Errorf("%s section parser kindList is empty", sectionName)
    return
  }
  logger.Debugf("%s - section %s start", c.Desc, sectionName)
  c.provider.Print(kinds[0], sectionName)
  c.dealer.setNext()
}

//----------------------------------------------------------------//
// PutLine
//----------------------------------------------------------------//
func (c *Composer) PutLine(line string) {
  if *c.skipLineCount == 0 {
    c.writer.Write(line)
  }
}

//----------------------------------------------------------------//
// Run
//----------------------------------------------------------------//
func (c *Composer) Run(reader io.Reader) ApiRecord {
  err := c.provider.Start()
  if err != nil {
    return c.WithErr(err)
  }

  handler := han.NewScanHandler(c, c.skipLineCount)

  err = handler.Run(reader)
  return c.CheckErr(err)
}

//----------------------------------------------------------------//
// String
//----------------------------------------------------------------//
func (c *Composer) String() string {
  return c.Desc
}

//----------------------------------------------------------------//
// skipLines
//----------------------------------------------------------------//
func (c *Composer) skipLines(skipLineCount int) {
  *c.skipLineCount = skipLineCount
}

//----------------------------------------------------------------//
// UseToken
//----------------------------------------------------------------//
func (c *Composer) UseToken(sd *ScanData) {}
