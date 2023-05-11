// The MIT License
//
// Copyright (c) 2023 Peter A McGill
package std

import (
  "fmt"
  "net"

  "github.com/pcbuildpluscoding/apibase/loggar"
  prg "github.com/pcbuildpluscoding/cibuild/lib/codegen/progen"
  tdb "github.com/pcbuildpluscoding/trovedb/std"
  gwt "github.com/pcbuildpluscoding/types/genware"
  rwt "github.com/pcbuildpluscoding/types/runware"
  "github.com/sirupsen/logrus"
)

var logger = loggar.Get()

// -------------------------------------------------------------- //
// SetLogger
// ---------------------------------------------------------------//
func SetLogger(super *logrus.Logger) {
  logger = super
}

type Genware = gwt.Genware
type GenwareVendor = gwt.GenwareVendor
type Runware = rwt.Runware
type Trovian = tdb.Trovian

//------------------------------------------------------------------//
// init - register genware plugins
//------------------------------------------------------------------//
func init() {
  pkey := "codegen/progen/std"
  vendor := NewProGenVendor()
  gwt.RegisterGenware(pkey, vendor)
}

//----------------------------------------------------------------//
// NewProGenVendor
//----------------------------------------------------------------//
func NewProGenVendor() GenwareVendor {
  return func(netAddr string, rw Runware) (Genware, error) {
    connex,err := newTrovian(netAddr, rw.String("BucketName"))
    if err != nil {
      return nil, err
    }
    writer, err := prg.NewWriter(connex, "ProGen", rw.String("Action"), rw.String("OutputFile"))
    if err != nil {
      return nil, err
    } 
    return prg.NewPGProducer(connex, rw, writer)
  }
}

// ---------------------------------------------------------------//
// NewTrovian
// ---------------------------------------------------------------//
func newTrovian(netAddr, bucket string) (*Trovian, error) {

  logger.Debugf("dialing trovedb address %s ...", netAddr)
  
  conn, err := net.Dial("tcp", netAddr)
  
  if err != nil {
    return nil, fmt.Errorf("dialing %s failed : %v", netAddr, err)
  } 

  return tdb.NewTrovian(conn, bucket)
}
