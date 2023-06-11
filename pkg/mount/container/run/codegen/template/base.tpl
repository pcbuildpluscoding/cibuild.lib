package run

import (
  "fmt"
  "os"
  "time"

  "github.com/pcbuildpluscoding/logroll"
  elm "github.com/pcbuildpluscoding/genware/lib/element"
  fs "github.com/pcbuildpluscoding/genware/lib/filesystem"
  han "github.com/pcbuildpluscoding/genware/lib/handler"
  stx "github.com/pcbuildpluscoding/strucex/std"
  tdb "github.com/pcbuildpluscoding/trovedb/std"
  rdt "github.com/pcbuildpluscoding/types/apirecord"
  rwt "github.com/pcbuildpluscoding/types/runware"
  "github.com/sirupsen/logrus"
)

type ApiRecord = rdt.ApiRecord
type Blacklist = elm.Blacklist
type Component = elm.Component
type DataDealer = elm.DataDealer
type ScanData = han.ScanData
type LineWriter = elm.LineWriter
type Printer = elm.Printer
type Runware = rwt.Runware
type StdPrinter = elm.StdPrinter
type TextConsumer = han.TextConsumer
type Trovian = tdb.Trovian
type VarDecErrTest = elm.VarDecErrTest
type XString = fs.XString

var (
  logger = logroll.Get()
  logfd *os.File
)

// -------------------------------------------------------------- //
// SetLogger
// ---------------------------------------------------------------//
func SetLogger(super *logrus.Logger, superfd *os.File) {
  logger = super
  logfd = superfd
}

//================================================================//
// TextEditor
//================================================================//
type TextEditor interface {
  Replace(*string)
  Start()
}

//================================================================//
// TextParser
//================================================================//
type TextParser interface {
  EditLine(*string)
  Arrange(Runware) error
  Next() TextParser
  PutLine(string)
  RemoveNext()
  SectionEnd()
  SectionStart(string)
  SetNext(TextParser)
  String() string
}

//----------------------------------------------------------------//
// NewCRProducer
//----------------------------------------------------------------//
func NewCRProducer(connex *Trovian, spec Runware) (*CRProducer, error) {
  logger.Debugf("$$$$$$$$$$$ creating CRProducer with spec : %v $$$$$$$$$$$", spec.AsMap())
  desc := "CRProducer-" + time.Now().Format("150405.000000")
  count := 0
  dd, err := elm.NewDataDealer(desc, connex, spec)
  if err != nil {
    return nil, err
  }
  provider := NewParserProvider(&dd, &count)
  rw := spec.SubNode("Arrangement")
  err = provider.Arrange(rw)
  if err != nil {
    return nil, err
  }
  dealer := NewSectionDealer(&count)
  err = dealer.Arrange(provider.dd, rw)
  if err != nil {
    return nil, err
  }
  return &CRProducer{
    Component: Component{Desc: desc},
    dealer: dealer,
    provider: provider,
    skipLineCount: &count,
  }, err
}

//----------------------------------------------------------------//
// NewCRComposer
//----------------------------------------------------------------//
func NewCRComposer(connex *Trovian, spec Runware, writer LineWriter) (*Composer, error) {
  logger.Debugf("$$$$$$$$$$$ creating Composer with spec : %v $$$$$$$$$$$", spec.AsMap())
  count := 0
  desc := "Composer-" + time.Now().Format("150405.000000")
  dd, err := elm.NewDataDealer(desc, connex, spec)
  if err != nil {
    return nil, err
  }
  provider := NewPrintProvider(&dd, writer)
  rw := spec.SubNode("Arrangement")
  err = provider.Arrange(rw)
  if err != nil {
    return nil, err
  }
  dealer := NewSectionDealer(&count)
  err = dealer.Arrange(provider.dd, rw)
  if err != nil {
    return nil, err
  }
  return &Composer{
    Component: Component{Desc: desc},
    dealer: dealer,
    skipLineCount: &count,
    provider: provider,
    writer: writer,
  }, err
}


//----------------------------------------------------------------//
// NewPrintProvider
//----------------------------------------------------------------//
func NewPrintProvider(dd *DataDealer, writer LineWriter) PrintProvider {
  desc := "PrintProvider-" + time.Now().Format("150405.000000")
  return PrintProvider{
    Desc: desc,
    dd: dd,
    cache: map[string]Printer{},
    writer: writer,
  }
}

//----------------------------------------------------------------//
// NewParserProvider
//----------------------------------------------------------------//
func NewParserProvider(dd *DataDealer, count *int) ParserProvider {
  desc := "ParserProvider-" + time.Now().Format("150405.000000")
  return ParserProvider{
    Desc: desc,
    dd: dd,
    cache: map[string]TextParser{},
    skipLineCount: count,
  }
}

//----------------------------------------------------------------//
// NewVarDecParser
//----------------------------------------------------------------//
func NewVarDecParser(dd *DataDealer, count *int, spec Runware) (*VarDecParser, error) {
  snip:1/VarDecParser/constructor
}

//----------------------------------------------------------------//
// NewLineCopier
//----------------------------------------------------------------//
func NewLineCopier(dd *DataDealer, count *int, darg ...string) LineCopier {
  snip:1/LineCopier/constructor
}

//----------------------------------------------------------------//
// NewLineEditor
//----------------------------------------------------------------//
func NewLineEditor(dd *DataDealer, count *int) (*LineEditor, error) {
  desc := "LineEditor-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &LineEditor{
    LineCopier: NewLineCopier(dd, count, desc),
  }, nil
}

//----------------------------------------------------------------//
// NewSectionDealer
//----------------------------------------------------------------//
func NewSectionDealer(count *int) SectionDealer {
  return SectionDealer{
    Desc: "SectionDealer-" + time.Now().Format("150405.000000"),
    skipLineCount: count,
  }
}

//----------------------------------------------------------------//
// NewVarDecErrTest
//----------------------------------------------------------------//
func NewVarDecErrTest(dd *DataDealer, spec Runware) (VarDecErrTest, error) {
  dbkey := spec.String("VarDecErrTest")
  if dbkey == "" {
    return VarDecErrTest{}, fmt.Errorf("VarDecErrTest creation requires a trovedb bucket key")
  } 
  rw, _ := stx.NewRunware(nil)
  err := dd.GetWithKey(dbkey, rw)
  return elm.NewVarDecErrTestA(rw), err
  }
