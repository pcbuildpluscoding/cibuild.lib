package run

import (
	"time"

	"github.com/pcbuildpluscoding/apibase/loggar"
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
type Component = elm.Component
type DataDealer = elm.DataDealer
type FlowRule = elm.FlowRule
type LineWriter = elm.LineWriter
type Printer = elm.Printer
type Runware = rwt.Runware
type ScanData = han.ScanData
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
// NewDVProducer
//----------------------------------------------------------------//
func NewDVProducer(connex *Trovian, spec Runware) (*DVProducer, error) {
  logger.Debugf("$$$$$$$$$$$ creating DVProducer with spec : %v $$$$$$$$$$$", spec.AsMap())
  desc := "DVProducer-" + time.Now().Format("150405.000000")
  provider, err := NewTCProvider(connex, spec)
  if err != nil {
    return nil, err
  }
  err = provider.Arrange(spec)
  return &DVProducer{
    Component: Component{Desc: desc},
    provider: provider,
  }, err
}

//----------------------------------------------------------------//
// NewDVComposer
//----------------------------------------------------------------//
func NewDVComposer(connex *Trovian, spec Runware, writer LineWriter) (*DVComposer, error) {
  logger.Debugf("$$$$$$$$$$$ creating CRComposer with spec : %v $$$$$$$$$$$", spec.AsMap())
  count := 0
  desc := "CRComposer-" + time.Now().Format("150405.000000")
  provider, err := NewPrintProvider(connex, spec, writer)
  if err != nil {
    return nil, err
  }
  err = provider.Arrange(spec)
  return &DVComposer{
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
func NewTCProvider(connex *Trovian, spec Runware) (TCProvider, error) {
  count := 0
  desc := "TCProvider-" + time.Now().Format("150405.000000")
  dd, err := elm.NewDataDealer(connex, desc, "", spec)
  return TCProvider{
    dd: &dd,
    cache: map[string]TextConsumer{},
    skipLineCount: &count,
  }, err
}

//----------------------------------------------------------------//
// NewDVExtractor
//----------------------------------------------------------------//
func NewDVExtractor(dd *DataDealer, skipLineCount *int) (*DVExtractor, error) {
  cache, _ := stx.NewRunware(nil)
  desc := "DVExtractor-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &DVExtractor{
    Component: Component{Desc: desc},
    dd: dd,
    cache: cache,
    skipLineCount: skipLineCount,
  }, nil
}

//----------------------------------------------------------------//
// NewImportExtractor
//----------------------------------------------------------------//
func NewImportExtractor(dd *DataDealer, skipLineCount *int) (*ImportExtractor, error) {
  desc := "ImportExtractor-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &ImportExtractor{
    Component: Component{Desc: desc},
    dd: dd,
    skipLineCount: skipLineCount,
  }, nil
}

//----------------------------------------------------------------//
// NewDVContentPrinter
//----------------------------------------------------------------//
func NewDVContentPrinter(dd *DataDealer, writer LineWriter) (*DVContentPrinter, error) {
  return &DVContentPrinter{
    Desc: "DVContentPrinter-" + time.Now().Format("150405.000000"),
    dd: dd,
    writer: writer,
  }, nil
}

//----------------------------------------------------------------//
// NewDVImportPrinter
//----------------------------------------------------------------//
func NewDVImportPrinter(dd *DataDealer, writer LineWriter) (*DVImportPrinter, error) {
  return &DVImportPrinter{
    Desc: "DVImportPrinter-" + time.Now().Format("150405.000000"),
    dd: dd,
    writer: writer,
  }, nil
}
