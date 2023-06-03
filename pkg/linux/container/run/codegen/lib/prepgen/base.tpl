package run

import (
	"io"
	"os"
	"time"

	"github.com/pcbuildpluscoding/apibase/loggar"
	elm "github.com/pcbuildpluscoding/genware/lib/element"
	tdb "github.com/pcbuildpluscoding/trovedb/std"
	rdt "github.com/pcbuildpluscoding/types/apirecord"
	rwt "github.com/pcbuildpluscoding/types/runware"
	"github.com/sirupsen/logrus"
)

type ApiRecord = rdt.ApiRecord
type Component = elm.Component
type LineWriter = elm.LineWriter
type Runware = rwt.Runware
type Trovian = tdb.Trovian

var (
  logger = loggar.Get()
  logfd *os.File
)

// -------------------------------------------------------------- //
// SetLogger
// ---------------------------------------------------------------//
func SetLogger(super *logrus.Logger, superfd *os.File) {
  logger = super
  logfd = superfd
}

//----------------------------------------------------------------//
// NewCRProducer
//----------------------------------------------------------------//
func NewCRProducer(connex *Trovian, spec Runware) (*CRProducer, error) {
  desc := "CRProducer-" + time.Now().Format("150405.000000")
  return &CRProducer{
    Component: Component{Desc: desc},
  }, nil
}

//================================================================//
// CRProducer
//================================================================//
type CRProducer struct {
  Component
}

//----------------------------------------------------------------//
// Run
//----------------------------------------------------------------//
func (p *CRProducer) Run(reader io.Reader) ApiRecord {
  return p.With(200)
}

//----------------------------------------------------------------//
// NewCRComposer
//----------------------------------------------------------------//
func NewCRComposer(connex *Trovian, spec Runware, writer LineWriter) (*CRComposer, error) {
  desc := "CRComposer-" + time.Now().Format("150405.000000")
  return &CRComposer{
    Component: Component{Desc: desc},
  }, nil
}

//================================================================//
// CRComposer
//================================================================//
type CRComposer struct {
  Component
}

//----------------------------------------------------------------//
// Run
//----------------------------------------------------------------//
func (p *CRComposer) Run(reader io.Reader) ApiRecord {
  return p.With(200)
}

