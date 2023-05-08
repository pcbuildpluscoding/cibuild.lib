package run

import (
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
  provider, err := NewTCProvider(connex, spec)
  if err != nil {
    return nil, err
  }
  err = provider.Arrange(spec)
  return &CRProducer{
    Component: Component{Desc: desc},
    provider: provider,
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
// NewLineCopierB
//----------------------------------------------------------------//
func NewLineCopierB(dd *DataDealer, skipLineCount *int) (*LineCopierB, error) {
  desc := "LineCopierB-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &LineCopierB{
    Component: Component{Desc: desc},
    dd: dd,
    skipLineCount: skipLineCount,
  }, nil
}

//----------------------------------------------------------------//
// NewLineCopierC
//----------------------------------------------------------------//
func NewLineCopierC(dd *DataDealer, skipLineCount *int) (*LineCopierC, error) {
  desc := "LineCopierC-" + time.Now().Format("150405.000000")
  return &LineCopierC{
    Component: Component{Desc: desc},
    dd: dd,
    skipLineCount: skipLineCount,
  }, nil
}

//----------------------------------------------------------------//
// NewVDExtractor
//----------------------------------------------------------------//
func NewVDExtractor(dd *DataDealer, skipLineCount *int) (*VDExtractor, error) {
  desc := "VDExtractor-" + time.Now().Format("150405.000000")
  dd.Desc = desc
  return &VDExtractor{
    Component: Component{Desc: desc},
    dd: dd,
    skipLineCount: skipLineCount,
  }, nil
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

