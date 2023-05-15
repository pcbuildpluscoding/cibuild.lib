// The MIT License
//
// Copyright (c) 2023 Peter A McGill
package std

import (
  "fmt"
  "net"

  "github.com/pcbuildpluscoding/apibase/loggar"
  crg "github.com/pcbuildpluscoding/cibuild/lib/create/container/run"
  elm "github.com/pcbuildpluscoding/genware/lib/element"
  tdb "github.com/pcbuildpluscoding/trovedb/std"
  gwk "github.com/pcbuildpluscoding/genware/genwork/cibuild/profile"
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
type Genwork = gwt.Genwork
type GenwareVendor = gwt.GenwareVendor
type GenworkVendor = gwt.GenworkVendor
type Runware = rwt.Runware
type Trovian = tdb.Trovian

//------------------------------------------------------------------//
// init - register plugins
//------------------------------------------------------------------//
func init() {
  pkey := "create/container/run"
  vendorA := NewCRGenVendor(pkey)
  gwt.RegisterGenware(pkey, vendorA)
  pkey = "cibuild/profile/edit"
  vendorB := NewEditProfileVendor()
  gwt.RegisterGenwork(pkey, vendorB)
}

//----------------------------------------------------------------//
// NewCRGenVendor
//----------------------------------------------------------------//
func NewCRGenVendor(pkey string) GenwareVendor {
  return func(netAddr string, rw Runware) (Genware, error) {
    connex, err := newTrovian(netAddr, rw.String("BucketName"))
    if err != nil {
      return nil, err
    }
    switch action := rw.String("Action"); action {
    case "ScanVars":
      return crg.NewCRProducer(connex, rw)
    case "Generate":
      writer, err := elm.NewWriter(connex, "VarDec", rw.String("OutputFile"))
      if err != nil {
        logger.Error(err)
        return nil, err
      } 
      return crg.NewCRComposer(connex, rw, writer)
    default:
      return nil, fmt.Errorf("unsupported %s action : %s", pkey, action)
    }
  }
}

//----------------------------------------------------------------//
// NewEditProfileVendor
//----------------------------------------------------------------//
func NewEditProfileVendor() GenworkVendor {
  return func(troveAddr string, rw Runware) (Genwork, error) {
    connex, err := newTrovian(troveAddr, rw.String("BucketName"))
    if err != nil {
      return nil, err
    }
    return gwk.NewProfileEditor(connex), nil
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