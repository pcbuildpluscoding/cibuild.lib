package progen

import (
	"fmt"
	"io"
	"time"

	"github.com/pcbuildpluscoding/apibase/loggar"
	ab "github.com/pcbuildpluscoding/apibase/std"
	elm "github.com/pcbuildpluscoding/genware/lib/element"
	fs "github.com/pcbuildpluscoding/genware/lib/filesystem"
	han "github.com/pcbuildpluscoding/genware/lib/handler"
	stx "github.com/pcbuildpluscoding/strucex/std"
	tdb "github.com/pcbuildpluscoding/trovedb/std"
	rdt "github.com/pcbuildpluscoding/types/apirecord"
	rwt "github.com/pcbuildpluscoding/types/runware"
	"github.com/sirupsen/logrus"
)

type ApiResult = ab.ApiResult
type ApiRecord = rdt.ApiRecord
type Component = elm.Component
type DataDealer = elm.DataDealer
type LineWriter = elm.LineWriter

type ScanData = han.ScanData
type TextConsumer = han.TextConsumer
type Trovian = tdb.Trovian
type Parameter rwt.Parameter
type Runware = rwt.Runware
type Strucex = stx.Strucex
type ValueA1 = stx.ValueA1
type XString = elm.XString

var logger = loggar.Get()

// -------------------------------------------------------------- //
// SetLogger
// ---------------------------------------------------------------//
func SetLogger(super *logrus.Logger) {
  logger = super
}

//----------------------------------------------------------------//
// NewContentBlock
//----------------------------------------------------------------//
func NewContentBlock(connex *Trovian, spec Runware) (*ContentBlock, error) {
  desc := "ContentBlock-" + time.Now().Format("150405.000000")
  sectionName := spec.String("SectionName")
  dd, err := elm.NewDataDealer(connex, desc, sectionName, spec)
  markup,_ := stx.NewRunware(nil)
  return &ContentBlock{
    Desc: desc,
    dd: &dd,
    markup: markup,
  }, err
}

//----------------------------------------------------------------//
// NewPGProducer
//----------------------------------------------------------------//
func NewPGProducer(connex *Trovian, spec Runware, writer LineWriter) (*PGProducer, error) {
  count := 0
  desc := "PGProducer-" + time.Now().Format("150405.000000")
  cblock, err := NewContentBlock(connex, spec)
  return &PGProducer{
    Component: Component{Desc: desc},
    block: cblock,
    skipLineCount: &count,
    writer: writer,
  }, err
}

//----------------------------------------------------------------//
// NewPGWriter
//----------------------------------------------------------------//
func NewPGWriter(w io.Writer) *PGWriter {
  return &PGWriter{
    writer: w,
  }
}

//================================================================//
// PGWriter
//================================================================//
type PGWriter struct {
  writer io.Writer
}

//----------------------------------------------------------------//
// SetProperty
//----------------------------------------------------------------//
func (w *PGWriter) SetProperty(propName string, value interface{}) error {
  return nil
}

//----------------------------------------------------------------//
// Write
//----------------------------------------------------------------//
func (w PGWriter) Write(lines ...interface{}) {
  for _, item := range lines {
    switch item.(type) {
    case []string:
      x := item.([]string)
      indent := x[0]
      for _, line := range x[1:] {
        w.PrintLine(XString(indent + line))
      }
    case string:
      w.PrintLine(XString(item.(string)))
    case []interface{}:
      x := item.([]interface{})
      w.Write(x...)
    default:
      logger.Warnf("StdWriter got an unexpected data type : %T\n", item)
      fmt.Fprintf(w.writer, "$$$$$$$$$ StdWriter got an unexpected data type : %T\n$$$$$$$$", item)
    }
  }
}

func (w PGWriter) PrintLine(xline XString) {
  switch {
  case xline.HasSuffix("// skip-new-line"):
    fmt.Fprint(w.writer, xline.Replace("// skip-new-line","",1).String())
  case xline.HasSuffix("// trim-space"):
    fmt.Fprintln(w.writer, xline.Replace("// trim-space","",1).Trim())
  default:
    fmt.Fprintln(w.writer, xline.String())
  }
}

// -------------------------------------------------------------- //
// NewWriter
// ---------------------------------------------------------------//
func NewWriter(connex *Trovian, model, action, outputPath string) (LineWriter, error) {

  switch model {
  case "Standard":
    switch action {
    case "Generate":
      writer, err := fs.CreateFile(connex, outputPath, false)
      return elm.NewStdWriter(writer), err
    }
  case "VarDec":
    switch action {
    case "Generate":
      writer, err := fs.CreateFile(connex, outputPath, false)
      return elm.NewVDWriter(writer), err
    }
  case "ProGen":
    writer, err := fs.CreateFile(connex, outputPath, false)
    return NewPGWriter(writer), err
  }
  return nil, fmt.Errorf("unsupported subject or action")
}

