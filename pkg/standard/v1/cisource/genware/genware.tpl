// The MIT License
//
// Copyright (c) 2023 Peter A McGill
package std

import (
  "fmt"
  "net"

  "github.com/pcbuildpluscoding/logroll"
  gwk "github.com/pcbuildpluscoding/cibuild/genwork/profile"
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
  vendor := NewEditProfileVendor()
  gwt.RegisterGenwork(pkey, vendor)
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