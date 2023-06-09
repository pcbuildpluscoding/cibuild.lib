package run

import (
  "io"
  "os"
  "time"

  "github.com/pcbuildpluscoding/logroll"
  elm "github.com/pcbuildpluscoding/genware/lib/element"
  tdb "github.com/pcbuildpluscoding/trovedb/std"
  rdt "github.com/pcbuildpluscoding/types/apirecord"
  rwt "github.com/pcbuildpluscoding/types/runware"
  "github.com/sirupsen/logrus"
)

type ApiRecord = rdt.ApiRecord
type Component = elm.Component
type Runware = rwt.Runware
type Trovian = tdb.Trovian

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

//----------------------------------------------------------------//
// NewPGComposer
//----------------------------------------------------------------//
func NewPGComposer(connex *Trovian, dealer SnipDealer) (*PGComposer, error) {
  desc := "PGComposer-" + time.Now().Format("150405.000000")
  return &PGComposer{
    Component: elm.Component{Desc: desc},
  }, nil
}

//----------------------------------------------------------------//
// NewSnipDealer
//----------------------------------------------------------------//
func NewSnipDealer(connex *Trovian) SnipDealer {
  return SnipDealer{
    Desc: "SnipDealer-" + time.Now().Format("150405.000000"),
  }
}

//================================================================//
// PGComposer
//================================================================//
type PGComposer struct {
  Component
}

//----------------------------------------------------------------//
// Run
//----------------------------------------------------------------//
func (c *PGComposer) Run(reader io.Reader) ApiRecord {
  return c.With(200)
}

//================================================================//
// SnipDealer
//================================================================//
type SnipDealer struct {
  Desc string
}

//----------------------------------------------------------------//
// Arrange
//----------------------------------------------------------------//
func (d *SnipDealer) Arrange(spec Runware) error {
  return nil
}