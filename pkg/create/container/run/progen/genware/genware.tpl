// The MIT License
//
// Copyright (c) 2023 Peter A McGill
package std

import (
	"fmt"
	"net"
	"strings"

	crg "github.com/pcbuildpluscoding/cibuild/lib/create/container/run"
	prg "github.com/pcbuildpluscoding/cibuild/lib/progen"
	gwk "github.com/pcbuildpluscoding/genware/genwork/cibuild/profile"
	elm "github.com/pcbuildpluscoding/genware/lib/element"
	fs "github.com/pcbuildpluscoding/genware/lib/filesystem"
	"github.com/pcbuildpluscoding/logroll"
	tdb "github.com/pcbuildpluscoding/trovedb/std"
	gwt "github.com/pcbuildpluscoding/types/genware"
	rwt "github.com/pcbuildpluscoding/types/runware"
	xstr "github.com/pcbuildpluscoding/xstring"
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
type XString = xstr.XString

//------------------------------------------------------------------//
// init - register plugins
//------------------------------------------------------------------//
func init() {
  pkey := "cibuild/profile/edit"
  vendorB := NewEditProfileVendor()
  gwt.RegisterGenwork(pkey, vendorB)
  pkey = "cibuild/progen/std"
  vendorA := NewPGGenVendor(pkey)
  gwt.RegisterGenware(pkey, vendorA)
  pkey = "create/container/run"
  vendorC := NewCRGenVendor(pkey)
  gwt.RegisterGenware(pkey, vendorC)
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
// NewPGGenVendor
//----------------------------------------------------------------//
func NewPGGenVendor(pkey string) GenwareVendor {
  return func(netAddr string, rw Runware) (Genware, error) {
    connex, err := newTrovian(netAddr, rw.String("BucketName"))
    if err != nil {
      return nil, err
    }
    switch action := rw.String("Action"); action {
    case "Generate":
      pkgName, fileName := resolveReqParams(rw.String("PackageFile"))
      logger.Debugf("Progen - got package and bucket : %s, %s", pkgName, fileName)
      rw.Set("Package", pkgName)
      bucketName := strings.Replace(rw.String("BucketName"),"<fileName>",fileName,1)
      connex.ToggleBucketName(bucketName)
      x := strings.Replace(rw.String("InputFile"), "<fileName>", fileName, 1)
      inputFile, err := fs.ResolvePath(connex, x)
      if err != nil {
        return nil, err
      }
      logger.Debugf("Progen - got inputFile : %s", inputFile)
      rw.Set("InputFile", inputFile)
      outputFile := strings.Replace(rw.String("OutputFile"), "<package>/<fileName>", pkgName + "/" + fileName, 1)
      writer, err := prg.NewSnipWriter(connex, outputFile)
      if err != nil {
        return nil, err
      }
      logger.Debugf("$$$$$$ got snipWriter : %v $$$$$$$", writer)
      dealer := prg.NewSnipDealer(connex, writer)
      err = dealer.Arrange(rw)
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
// resolveReqParams
//----------------------------------------------------------------//
func resolveReqParams(pvalue string) (string, string) {
  pkgName, fileName := XString(pvalue).SplitInTwo("/")
  return pkgName.String(), fileName.String()
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
    return gwk.NewProfileEditor(connex)
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