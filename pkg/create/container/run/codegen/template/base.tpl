package run

import (
  "fmt"
  "os"
  "time"

  elm "github.com/pcbuildpluscoding/genware/lib/element"
  fs "github.com/pcbuildpluscoding/genware/lib/filesystem"
  han "github.com/pcbuildpluscoding/genware/lib/handler"
  "github.com/pcbuildpluscoding/logroll"
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
// LineParser
//================================================================//
type LineParser interface {
  Parse(*string)
  Start()
}

//================================================================//
// SectionParser
//================================================================//
type SectionParser interface {
  Arrange(Runware) error
  Next() SectionParser
  Parse(*string)
  PutLine(string)
  RemoveNext()
  SectionEnd()
  SectionStart(string)
  SetNext(SectionParser)
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
    cache: map[string]SectionParser{},
    skipLineCount: count,
  }
}

//----------------------------------------------------------------//
// NewVarDecParser
//----------------------------------------------------------------//
func NewVarDecParser(dd *DataDealer, count *int, spec Runware) (*VarDecParser, error) {
  desc := "VarDecParser-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  blacklist, err := elm.NewBlacklist(spec)
  if err != nil {
    return nil, err
  }
  return &VarDecParser{
    LineCopier: NewLineCopier(dd, count, desc),
    blacklist: blacklist,
    buffer: []interface{}{},
  }, nil
}

//----------------------------------------------------------------//
// NewLineCopier
//----------------------------------------------------------------//
func NewLineCopier(dd *DataDealer, count *int, darg ...string) LineCopier {
  desc := "LineCopier-" + time.Now().Format("150405.000000")
  if darg != nil {
    desc = darg[0]
  }
  return LineCopier{
    Desc: desc,
    dd: dd,
    skipLineCount: count,
  }
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
// LineJudge
//----------------------------------------------------------------//
func NewLineJudge(dd *DataDealer, count *int) (*LineJudge, error) {
  desc := "LineJudge-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &LineJudge{
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

//----------------------------------------------------------------//
// toInterfaceList
//----------------------------------------------------------------//
func toInterfaceList(indentSize int, x []string) []interface{} {
  indentFmt := "%" + fmt.Sprintf("%ds", indentSize)
  indent := fmt.Sprintf(indentFmt, " ")

  y := make([]interface{}, len(x))
  for i, z := range x {
    y[i] = indent + z
  }
  return y
}
