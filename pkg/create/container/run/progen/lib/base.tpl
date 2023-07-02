package run

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	ac "github.com/pcbuildpluscoding/apicore/std"
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
type Component = elm.Component
type DataDealer = elm.DataDealer
type ScanData = han.ScanData
type Parameter = stx.Parameter
type Printer = elm.Printer
type Runware = rwt.Runware
type Statial = ac.Statial
type StdPrinter = elm.StdPrinter
type TextConsumer = han.TextConsumer
type Trovian = tdb.Trovian
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
// LineWriter
//================================================================//
type LineWriter interface {
  Write(...string)
}

//----------------------------------------------------------------//
// NewPGComposer
//----------------------------------------------------------------//
func NewPGComposer(connex *Trovian, dealer SnipDealer) (*PGComposer, error) {
  logger.Debugf("$$$$$$$$$$$ creating PGComposer $$$$$$$$$$$")
  count := 0
  desc := "PGComposer-" + time.Now().Format("150405.000000")
  return &PGComposer{
    Statial: ac.NewStatial(desc),
    dealer: dealer,
    skipLineCount: &count,
  }, nil
}

//----------------------------------------------------------------//
// NewSnipDealer
//----------------------------------------------------------------//
func NewSnipDealer(connex *Trovian, writer SnipWriter) SnipDealer {
  return SnipDealer{
    Desc: "SnipDealer-" + time.Now().Format("150405.000000"),
    connex: connex,
    writer: writer,
  }
}

// -------------------------------------------------------------- //
// NewWriter
// ---------------------------------------------------------------//
func NewSnipWriter(connex *Trovian, outputPath string) (SnipWriter, error) {

  writer, err := fs.CreateFile(connex, outputPath, false)
  return SnipWriter{writer: writer}, err
}

// -------------------------------------------------------------- //
// createFile
// ---------------------------------------------------------------//
func createFile(connex *Trovian, outputPath string, index ...int) (*os.File, error) {

  if outputPath == "Stdout" {
    return os.Stdout, nil
  }
  
  if strings.HasPrefix(outputPath, "trovedb:") {
    var err error
    outputPath, err = fs.ResolvePath(connex, outputPath)
    if err != nil {
      logger.Error(err)
      return nil, err
    }
    logger.Infof("resolved output file path : %s", outputPath)
  }

  outputDir := filepath.Dir(outputPath)

  _, err := os.Stat(outputDir)
  if errors.Is(err, os.ErrNotExist) {
    if err := os.MkdirAll(outputDir, 0755); err != nil {
      return nil, fmt.Errorf("output directory |%s| creation failed : %v", outputDir, err)
    }
  }

  if index != nil && index[0] >= 0 {
    fileName := filepath.Base(outputPath)
    ext := filepath.Ext(fileName)
    x := strings.Replace(fileName, ext, "", 1)
    fileName = fmt.Sprintf("%s-%02d%s", x, index[0], ext)
    logger.Infof("!!!!!! appended an index to the output file : %s !!!!!!", fileName)
    outputPath = filepath.Join(outputDir, fileName)
  }

  return os.Create(outputPath)
}


