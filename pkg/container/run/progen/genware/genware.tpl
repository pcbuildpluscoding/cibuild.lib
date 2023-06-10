// The MIT License
//
// Copyright (c) 2023 Peter A McGill
package std

import (
  "fmt"
  "net"

  "github.com/pcbuildpluscoding/logroll"
  ccr "github.com/pcbuildpluscoding/cibuild/lib/create/container/run"
  lcr "github.com/pcbuildpluscoding/cibuild/lib/linux/container/run"
  prg "github.com/pcbuildpluscoding/cibuild/lib/progen"
  gwk "github.com/pcbuildpluscoding/genware/genwork/cibuild/profile"
  elm "github.com/pcbuildpluscoding/genware/lib/element"
  tdb "github.com/pcbuildpluscoding/trovedb/std"
  gwt "github.com/pcbuildpluscoding/types/genware"
  rwt "github.com/pcbuildpluscoding/types/runware"
  "github.com/sirupsen/logrus"
)

var logger = logroll.Get()

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
  pkey := "cibuild/profile/edit"
  vendorA := NewEditProfileVendor()
  gwt.RegisterGenwork(pkey, vendorA)
  pkey = "cibuild/progen/std"
  vendorB := NewPGGenVendor(pkey)
  gwt.RegisterGenware(pkey, vendorB)
  pkey = "create/container/run"
  vendorC := NewCCRGenVendor(pkey)
  gwt.RegisterGenware(pkey, vendorC)
  pkey = "linux/container/run"
  vendorD := NewLCRGenVendor(pkey)
  gwt.RegisterGenware(pkey, vendorD)
}

//----------------------------------------------------------------//
// NewCCRGenVendor
//----------------------------------------------------------------//
func NewCCRGenVendor(pkey string) GenwareVendor {
  return func(netAddr string, rw Runware) (Genware, error) {
    connex, err := newTrovian(netAddr, rw.String("BucketName"))
    if err != nil {
      return nil, err
    }
    switch action := rw.String("Action"); action {
    case "ScanVars":
      return ccr.NewCRProducer(connex, rw)
    case "Generate":
      writer, err := elm.NewWriter(connex, "VarDec", rw.String("OutputFile"))
      if err != nil {
        logger.Error(err)
        return nil, err
      } 
      return ccr.NewCRComposer(connex, rw, writer)
    default:
      return nil, fmt.Errorf("unsupported %s action : %s", pkey, action)
    }
  }
}

//----------------------------------------------------------------//
// NewLCRGenVendor
//----------------------------------------------------------------//
func NewLCRGenVendor(pkey string) GenwareVendor {
  return func(netAddr string, rw Runware) (Genware, error) {
    connex, err := newTrovian(netAddr, rw.String("BucketName"))
    if err != nil {
      return nil, err
    }
    switch action := rw.String("Action"); action {
    case "ScanVars":
      return lcr.NewCRProducer(connex, rw)
    case "Generate":
      writer, err := elm.NewWriter(connex, "VarDec", rw.String("OutputFile"))
      if err != nil {
        logger.Error(err)
        return nil, err
      } 
      return lcr.NewCRComposer(connex, rw, writer)
    default:
      return nil, fmt.Errorf("unsupported %s action : %s", pkey, action)
    }
  }
}

//----------------------------------------------------------------//
// NewPGGenVendor
//----------------------------------------------------------------//
func NewPGGenVendor(pkey string) GenwareVendor {
  return func(netAddr string, spec Runware) (Genware, error) {
    connex, err := newTrovian(netAddr, spec.String("BucketName"))
    if err != nil {
      return nil, err
    }
    switch action := spec.String("Action"); action {
    case "Generate":
      dealer := prg.NewSnipDealer(connex)
      err := dealer.Arrange(spec)
      if err != nil {
        return nil, err
      }
      return prg.NewPGComposer(connex, dealer)
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