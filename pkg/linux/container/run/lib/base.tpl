package run

import (
	"fmt"
	"time"

	"github.com/pcbuildpluscoding/apibase/loggar"
	elm "github.com/pcbuildpluscoding/genware/lib/element"
	fs "github.com/pcbuildpluscoding/genware/lib/filesystem"
	han "github.com/pcbuildpluscoding/genware/lib/handler"
	tdb "github.com/pcbuildpluscoding/trovedb/std"
	rdt "github.com/pcbuildpluscoding/types/apirecord"
	rwt "github.com/pcbuildpluscoding/types/runware"
	"github.com/sirupsen/logrus"
)

type ApiRecord = rdt.ApiRecord
type Component = elm.Component
type DataDealer = elm.DataDealer
type ScanData = han.ScanData
type LineWriter = elm.LineWriter
type Printer = elm.Printer
type Runware = rwt.Runware
type StdPrinter = elm.StdPrinter
type TextConsumer = han.TextConsumer
type Trovian = tdb.Trovian
type XString = fs.XString

var logger = loggar.Get()

// -------------------------------------------------------------- //
// SetLogger
// ---------------------------------------------------------------//
func SetLogger(super *logrus.Logger) {
  logger = super
}

//----------------------------------------------------------------//
// NewCRProducer
//----------------------------------------------------------------//
func NewCRProducer(connex *Trovian, spec Runware) (*CRProducer, error) {
  logger.Debugf("$$$$$$$$$$$ creating CRProducer with spec : %v $$$$$$$$$$$", spec.AsMap())
  desc := "CRProducer-" + time.Now().Format("150405.000000")
  count := 0
  provider, err := NewTCProvider(connex, spec, &count)
  if err != nil {
    return nil, err
  }
  rw := spec.SubNode("Arrangement")
  if rw.String("BucketName") == "" {
    return nil, fmt.Errorf("%s - required jobspec bucketName is undefined", desc)
  }
  provider.dd.ToggleBucketName(rw.String("BucketName"))
  err = provider.Arrange(rw)
  if err != nil {
    return nil, err
  }
  dealer := NewSectionDealer(&count)
  err = dealer.Arrange(provider.dd, rw)
  if err != nil {
    return nil, err
  }
  provider.dd.ToggleBucketName()
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
func NewCRComposer(connex *Trovian, spec Runware, writer LineWriter) (*CRComposer, error) {
  logger.Debugf("$$$$$$$$$$$ creating CRComposer with spec : %v $$$$$$$$$$$", spec.AsMap())
  count := 0
  desc := "CRComposer-" + time.Now().Format("150405.000000")
  provider, err := NewPrintProvider(connex, spec, writer)
  if err != nil {
    return nil, err
  }
  err = provider.Arrange(spec)
  return &CRComposer{
    Component: Component{Desc: desc},
    skipLineCount: &count,
    provider: provider,
    writer: writer,
  }, err
}

//----------------------------------------------------------------//
// NewPrintProvider
//----------------------------------------------------------------//
func NewPrintProvider(connex *Trovian, spec Runware, writer LineWriter) (PrintProvider, error) {
  desc := "PrintProvider-" + time.Now().Format("150405.000000")
  dd, err := elm.NewDataDealer(connex, desc, "", spec)
  return PrintProvider{
    dd: &dd,
    cache: map[string]Printer{},
    writer: writer,
  }, err
}

//----------------------------------------------------------------//
// NewTCProvider
//----------------------------------------------------------------//
func NewTCProvider(connex *Trovian, spec Runware, count *int) (TCProvider, error) {
  desc := "TCProvider-" + time.Now().Format("150405.000000")
  dd, err := elm.NewDataDealer(connex, desc, "", spec)
  return TCProvider{
    dd: &dd,
    cache: map[string]TextParser{},
    skipLineCount: count,
  }, err
}

//----------------------------------------------------------------//
// NewVardecPrinter
//----------------------------------------------------------------//
func NewVardecPrinter(dd *DataDealer, writer LineWriter) (*VardecPrinter, error) {
  p, err := elm.NewStdPrinter(dd, writer)
  p.Desc = "VardecPrinter-" + time.Now().Format("150405.000000")
  return &VardecPrinter{
    StdPrinter: *p,
  }, err
}

//----------------------------------------------------------------//
// NewLineCopier
//----------------------------------------------------------------//
func NewLineCopier(dd *DataDealer, count *int, darg ...string) LineCopier {
  desc := "LineParserA-" + time.Now().Format("150405.000000")
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
// NewLineParserA
//----------------------------------------------------------------//
func NewLineParserA(dd *DataDealer, count *int) (*LineParserA, error) {
  desc := "LineParserA-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &LineParserA{
    LineCopier: NewLineCopier(dd, count, desc),
    buffer: []interface{}{},
  }, nil
}

//----------------------------------------------------------------//
// NewLineParserB
//----------------------------------------------------------------//
func NewLineParserB(dd *DataDealer, count *int) (*LineParserB, error) {
  desc := "LineParserB-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &LineParserB{
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